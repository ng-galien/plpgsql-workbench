import type { Expression, Loc, Param, PlxEntity, PlxFunction, PlxModule, PlxSubscription, Statement } from "./ast.js";
import { CHANGE_HANDLER_PARAMS } from "./ast.js";
import {
  assignStmt,
  castExpr,
  fieldAccessExpr,
  identifierExpr,
  jsonObj,
  nullLiteral,
  textLiteral,
} from "./ast-builders.js";
import type { ModuleContract } from "./contract.js";
import type { DdlArtifact } from "./entity-ddl.js";
import { sqlEscape } from "./util.js";

interface EventExpandOptions {
  dependencyContracts?: Map<string, ModuleContract>;
}

interface EventExpandResult {
  ddlArtifacts: DdlArtifact[];
  ddlFragments: string[];
  errors: EventExpandError[];
  functions: PlxFunction[];
}

interface EventExpandError {
  entityName?: string;
  loc: Loc;
  message: string;
}

export function expandEvents(mod: PlxModule, options: EventExpandOptions = {}): EventExpandResult {
  const ddlArtifacts: DdlArtifact[] = [];
  const ddlFragments: string[] = [];
  const errors: EventExpandError[] = [];
  const functions: PlxFunction[] = [];
  const producerSchemas = new Set<string>();

  for (const entity of mod.entities) {
    if (entity.changeHandlers.length > 0 && !producerSchemas.has(entity.schema)) {
      producerSchemas.add(entity.schema);
      const busArtifacts = buildSchemaBusArtifacts(entity.schema);
      ddlArtifacts.push(...busArtifacts);
      ddlFragments.push(...busArtifacts.map((a) => a.sql));
    }

    functions.push(...buildEntityChangeHandlerFunctions(entity, errors));

    const triggerArtifacts = buildEntityTriggerArtifacts(entity);
    ddlArtifacts.push(...triggerArtifacts);
    ddlFragments.push(...triggerArtifacts.map((a) => a.sql));
  }

  mod.subscriptions.forEach((subscription, index) => {
    const contract = resolveEventContract(mod, subscription, options.dependencyContracts);
    if (contract && contract.params.length !== subscription.params.length) {
      errors.push({
        loc: subscription.loc,
        message: `subscription ${subscription.sourceSchema}.${subscription.sourceEntity}.${subscription.event} expects ${contract.params.length} parameter(s)`,
      });
      return;
    }

    const handler = buildSubscriptionHandler(mod, subscription, contract?.params, index);
    functions.push(handler);

    const artifact = buildSubscriptionRegistrationArtifact(mod, subscription, handler, contract?.params, index);
    ddlArtifacts.push(artifact);
    ddlFragments.push(artifact.sql);
  });

  return { functions, ddlFragments, ddlArtifacts, errors };
}

function buildSchemaBusArtifacts(schema: string): DdlArtifact[] {
  const outboxKey = `ddl:event-outbox:${schema}`;
  const subscriptionKey = `ddl:event-subscription:${schema}`;
  const deliveryKey = `ddl:event-delivery:${schema}`;
  const emitFnKey = `ddl:event-emit-fn:${schema}`;
  const dispatchFnKey = `ddl:event-dispatch-fn:${schema}`;

  return [
    {
      key: outboxKey,
      name: `${schema}._event_outbox`,
      dependsOn: [`ddl:schema:${schema}`],
      sql: `CREATE TABLE IF NOT EXISTS ${schema}._event_outbox (
  id bigserial PRIMARY KEY,
  event_name text NOT NULL,
  aggregate_type text NOT NULL,
  aggregate_id text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  txid bigint NOT NULL DEFAULT txid_current(),
  causation_id bigint,
  correlation_id text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);`,
    },
    {
      key: subscriptionKey,
      name: `${schema}._event_subscription`,
      dependsOn: [`ddl:schema:${schema}`],
      sql: `CREATE TABLE IF NOT EXISTS ${schema}._event_subscription (
  event_name text NOT NULL,
  consumer_module text NOT NULL,
  consumer_key text NOT NULL,
  call_sql text NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  PRIMARY KEY (event_name, consumer_key)
);`,
    },
    {
      key: deliveryKey,
      name: `${schema}._event_delivery`,
      dependsOn: [outboxKey],
      sql: `CREATE TABLE IF NOT EXISTS ${schema}._event_delivery (
  event_id bigint NOT NULL REFERENCES ${schema}._event_outbox(id) ON DELETE CASCADE,
  consumer_key text NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, consumer_key)
);`,
    },
    {
      key: emitFnKey,
      name: `${schema}._emit_event`,
      dependsOn: [outboxKey],
      sql: `CREATE OR REPLACE FUNCTION ${schema}._emit_event(
  p_event_name text,
  p_aggregate_type text,
  p_aggregate_id text,
  p_payload jsonb,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
  v_event_id bigint;
  v_causation_id bigint;
  v_correlation_id text;
BEGIN
  v_causation_id := nullif(current_setting('plx.current_event_id', true), '')::bigint;
  v_correlation_id := nullif(current_setting('plx.correlation_id', true), '');
  IF v_correlation_id IS NULL THEN
    v_correlation_id := txid_current()::text;
  END IF;

  INSERT INTO ${schema}._event_outbox (
    event_name,
    aggregate_type,
    aggregate_id,
    payload,
    metadata,
    causation_id,
    correlation_id
  ) VALUES (
    p_event_name,
    p_aggregate_type,
    p_aggregate_id,
    COALESCE(p_payload, '{}'::jsonb),
    COALESCE(p_metadata, '{}'::jsonb),
    v_causation_id,
    v_correlation_id
  )
  RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$$;`,
    },
    {
      key: dispatchFnKey,
      name: `${schema}._dispatch_event`,
      dependsOn: [outboxKey, subscriptionKey, deliveryKey],
      sql: `CREATE OR REPLACE FUNCTION ${schema}._dispatch_event() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  rec record;
BEGIN
  IF pg_trigger_depth() > 32 THEN
    RAISE EXCEPTION '${schema}.err_event_dispatch_depth';
  END IF;

  PERFORM set_config('plx.current_event_id', NEW.id::text, true);
  PERFORM set_config('plx.correlation_id', NEW.correlation_id, true);

  FOR rec IN
    SELECT consumer_key, call_sql
    FROM ${schema}._event_subscription
    WHERE enabled
      AND event_name = NEW.event_name
  LOOP
    INSERT INTO ${schema}._event_delivery (event_id, consumer_key)
    VALUES (NEW.id, rec.consumer_key)
    ON CONFLICT DO NOTHING;

    IF FOUND THEN
      EXECUTE rec.call_sql USING NEW.payload;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS _dispatch_event_trigger ON ${schema}._event_outbox;
CREATE TRIGGER _dispatch_event_trigger
AFTER INSERT ON ${schema}._event_outbox
FOR EACH ROW
EXECUTE FUNCTION ${schema}._dispatch_event();`,
    },
  ];
}

function buildEntityChangeHandlerFunctions(entity: PlxEntity, errors: EventExpandError[]): PlxFunction[] {
  const functions: PlxFunction[] = [];
  const events = new Map(entity.events.map((event) => [event.name, event]));

  for (const handler of entity.changeHandlers) {
    const expected = CHANGE_HANDLER_PARAMS.get(handler.operation) ?? [];
    const renamedParams = expected.map((param) => `p_${param}`);
    const renameMap = new Map(expected.map((param, index) => [param, renamedParams[index] ?? param]));

    functions.push({
      kind: "function",
      visibility: "internal",
      schema: entity.schema,
      name: `${entity.name}_on_${handler.operation}`,
      params: expected.map((param, index) => ({
        name: renamedParams[index] ?? `p_${param}`,
        type: entity.table,
        nullable: false,
        loc: entity.loc,
      })),
      returnType: "void",
      setof: false,
      attributes: [],
      body: transformStatements(handler.body, entity, handler.operation, events, errors, renameMap),
      loc: entity.loc,
    });
  }

  return functions;
}

function buildEntityTriggerArtifacts(entity: PlxEntity): DdlArtifact[] {
  if (entity.changeHandlers.length === 0) return [];

  const bodyLines = [
    "BEGIN",
    "  IF TG_OP = 'INSERT' THEN",
    hasHandler(entity, "insert") ? `    PERFORM ${entity.schema}.${entity.name}_on_insert(NEW);` : "    NULL;",
    "    RETURN NEW;",
    "  ELSIF TG_OP = 'UPDATE' THEN",
    hasHandler(entity, "update") ? `    PERFORM ${entity.schema}.${entity.name}_on_update(NEW, OLD);` : "    NULL;",
    "    RETURN NEW;",
    "  ELSIF TG_OP = 'DELETE' THEN",
    hasHandler(entity, "delete") ? `    PERFORM ${entity.schema}.${entity.name}_on_delete(OLD);` : "    NULL;",
    "    RETURN OLD;",
    "  END IF;",
    "  RETURN COALESCE(NEW, OLD);",
    "END;",
  ];

  return [
    {
      key: `ddl:event-trigger-fn:${entity.table}`,
      name: `${entity.table}.event_trigger`,
      dependsOn: [`ddl:table:${entity.table}`],
      sql: `CREATE OR REPLACE FUNCTION ${entity.schema}.${entity.name}_event_trigger() RETURNS trigger
LANGUAGE plpgsql
AS $$
${bodyLines.join("\n")}
$$;`,
    },
    {
      key: `ddl:event-trigger:${entity.table}`,
      name: `${entity.table}.event_trigger`,
      dependsOn: [`ddl:event-trigger-fn:${entity.table}`, `ddl:table:${entity.table}`],
      sql: `DROP TRIGGER IF EXISTS ${entity.name}_event_trigger ON ${entity.table};
CREATE TRIGGER ${entity.name}_event_trigger
AFTER INSERT OR UPDATE OR DELETE ON ${entity.table}
FOR EACH ROW
EXECUTE FUNCTION ${entity.schema}.${entity.name}_event_trigger();`,
    },
  ];
}

function hasHandler(entity: PlxEntity, operation: "insert" | "update" | "delete"): boolean {
  return entity.changeHandlers.some((handler) => handler.operation === operation);
}

function buildSubscriptionHandler(
  mod: PlxModule,
  subscription: PlxSubscription,
  eventParams: Param[] | undefined,
  index: number,
): PlxFunction {
  const schema = mod.name ?? subscription.sourceSchema;
  const params = subscription.params.map((name, idx) => ({
    name,
    type: eventParams?.[idx]?.type ?? "jsonb",
    nullable: Boolean(eventParams?.[idx]?.nullable),
    loc: subscription.loc,
  }));

  return {
    kind: "function",
    visibility: "internal",
    schema,
    name: `on_${subscription.sourceSchema}_${subscription.sourceEntity}_${subscription.event}_${index + 1}`,
    params,
    returnType: "void",
    setof: false,
    attributes: [],
    body: subscription.body,
    loc: subscription.loc,
  };
}

function buildSubscriptionRegistrationArtifact(
  mod: PlxModule,
  subscription: PlxSubscription,
  handler: PlxFunction,
  eventParams: Param[] | undefined,
  index: number,
): DdlArtifact {
  const consumerModule = mod.name ?? handler.schema;
  const eventName = `${subscription.sourceSchema}.${subscription.sourceEntity}.${subscription.event}`;
  const consumerKey = `${consumerModule}.${handler.name}`;
  const sourceParamNames = eventParams?.map((param) => param.name) ?? subscription.params;
  const argSql = handler.params.map((param, idx) => accessPayloadSql(sourceParamNames[idx] ?? param.name, param.type));
  const callSql = `SELECT ${handler.schema}.${handler.name}(${argSql.join(", ")})`;

  return {
    key: `ddl:event-registration:${consumerModule}:${subscription.sourceSchema}.${subscription.sourceEntity}.${subscription.event}:${index + 1}`,
    name: `${consumerKey}.registration`,
    dependsOn: [`ddl:event-subscription:${subscription.sourceSchema}`],
    sql: `INSERT INTO ${subscription.sourceSchema}._event_subscription (
  event_name,
  consumer_module,
  consumer_key,
  call_sql,
  enabled
) VALUES (
  '${sqlEscape(eventName)}',
  '${sqlEscape(consumerModule)}',
  '${sqlEscape(consumerKey)}',
  '${sqlEscape(callSql)}',
  true
)
ON CONFLICT (event_name, consumer_key) DO UPDATE
SET
  consumer_module = EXCLUDED.consumer_module,
  call_sql = EXCLUDED.call_sql,
  enabled = EXCLUDED.enabled;`,
  };
}

function resolveEventContract(
  mod: PlxModule,
  subscription: PlxSubscription,
  dependencyContracts?: Map<string, ModuleContract>,
): { params: Param[] } | undefined {
  const localEntity = mod.entities.find(
    (entity) => entity.schema === subscription.sourceSchema && entity.name === subscription.sourceEntity,
  );
  const localEvent = localEntity?.events.find((event) => event.name === subscription.event);
  if (localEvent) return { params: localEvent.params };

  const contract = dependencyContracts?.get(subscription.sourceSchema);
  const symbol = contract?.exports.find(
    (entry) =>
      entry.kind === "event" &&
      entry.schema === subscription.sourceSchema &&
      entry.name === `${subscription.sourceEntity}.${subscription.event}`,
  );
  return symbol?.params ? { params: symbol.params } : undefined;
}

function transformStatements(
  stmts: Statement[],
  entity: PlxEntity,
  operation: "insert" | "update" | "delete",
  events: Map<string, PlxEntity["events"][number]>,
  errors: EventExpandError[],
  renameMap: Map<string, string>,
): Statement[] {
  return stmts.map((stmt) => transformStatement(stmt, entity, operation, events, errors, renameMap));
}

function transformStatement(
  stmt: Statement,
  entity: PlxEntity,
  operation: "insert" | "update" | "delete",
  events: Map<string, PlxEntity["events"][number]>,
  errors: EventExpandError[],
  renameMap: Map<string, string>,
): Statement {
  switch (stmt.kind) {
    case "emit": {
      const event = events.get(stmt.eventName);
      if (!event) {
        errors.push({
          entityName: `${entity.schema}.${entity.name}`,
          loc: stmt.loc,
          message: `unknown entity event '${stmt.eventName}'`,
        });
        return assignStmt("_", nullLiteral(stmt.loc), stmt.loc);
      }

      const aggregateVar = operation === "delete" ? "old" : "new";
      const aggregateParam = renameMap.get(aggregateVar) ?? aggregateVar;
      const payload = jsonObj(
        event.params.map((param, index) => ({
          key: param.name,
          value: renameExpression(stmt.args[index] ?? nullLiteral(stmt.loc), renameMap),
        })),
        stmt.loc,
      );

      return assignStmt(
        "_",
        {
          kind: "call",
          name: `${entity.schema}._emit_event`,
          args: [
            textLiteral(`${entity.schema}.${entity.name}.${event.name}`, stmt.loc),
            textLiteral(`${entity.schema}.${entity.name}`, stmt.loc),
            castExpr(fieldAccessExpr(aggregateParam, "id", stmt.loc), identifierExpr("text", stmt.loc), stmt.loc),
            payload,
            jsonObj(
              [
                { key: "operation", value: textLiteral(operation, stmt.loc) },
                { key: "entity", value: textLiteral(`${entity.schema}.${entity.name}`, stmt.loc) },
              ],
              stmt.loc,
            ),
          ],
          loc: stmt.loc,
        },
        stmt.loc,
      );
    }
    case "assign":
      return {
        ...stmt,
        target: renameMap.get(stmt.target) ?? stmt.target,
        value: renameExpression(stmt.value, renameMap),
      };
    case "append":
      return {
        ...stmt,
        target: renameMap.get(stmt.target) ?? stmt.target,
        value: renameExpression(stmt.value, renameMap),
      };
    case "assert":
      return { ...stmt, expression: renameExpression(stmt.expression, renameMap) };
    case "if":
      return {
        ...stmt,
        condition: renameExpression(stmt.condition, renameMap),
        body: transformStatements(stmt.body, entity, operation, events, errors, renameMap),
        elsifs: stmt.elsifs.map((elsif) => ({
          condition: renameExpression(elsif.condition, renameMap),
          body: transformStatements(elsif.body, entity, operation, events, errors, renameMap),
        })),
        elseBody: stmt.elseBody
          ? transformStatements(stmt.elseBody, entity, operation, events, errors, renameMap)
          : undefined,
      };
    case "for_in":
      return {
        ...stmt,
        variable: renameMap.get(stmt.variable) ?? stmt.variable,
        body: transformStatements(stmt.body, entity, operation, events, errors, renameMap),
      };
    case "try_catch":
      return {
        ...stmt,
        body: transformStatements(stmt.body, entity, operation, events, errors, renameMap),
        catchBody: transformStatements(stmt.catchBody, entity, operation, events, errors, renameMap),
      };
    case "match":
      return {
        ...stmt,
        subject: renameExpression(stmt.subject, renameMap),
        arms: stmt.arms.map((arm) => ({
          pattern: renameExpression(arm.pattern, renameMap),
          body: transformStatements(arm.body, entity, operation, events, errors, renameMap),
        })),
        elseBody: stmt.elseBody
          ? transformStatements(stmt.elseBody, entity, operation, events, errors, renameMap)
          : undefined,
      };
    case "return":
      return { ...stmt, value: renameExpression(stmt.value, renameMap) };
    case "raise":
    case "sql_statement":
      return stmt;
  }
}

function renameExpression(expr: Expression, renameMap: Map<string, string>): Expression {
  switch (expr.kind) {
    case "identifier":
      return { ...expr, name: renameMap.get(expr.name) ?? expr.name };
    case "field_access":
      return { ...expr, object: renameMap.get(expr.object) ?? expr.object };
    case "array_literal":
      return { ...expr, elements: expr.elements.map((element) => renameExpression(element, renameMap)) };
    case "binary":
      return {
        ...expr,
        left: renameExpression(expr.left, renameMap),
        right: renameExpression(expr.right, renameMap),
      };
    case "call":
      return {
        ...expr,
        args: expr.args.map((arg) => ({
          ...("kind" in arg ? { value: arg, loc: arg.loc } : arg),
          value: renameExpression("kind" in arg ? arg : arg.value, renameMap),
        })),
      };
    case "case_expr":
      return {
        ...expr,
        subject: renameExpression(expr.subject, renameMap),
        arms: expr.arms.map((arm) => ({
          pattern: renameExpression(arm.pattern, renameMap),
          result: renameExpression(arm.result, renameMap),
        })),
        elseResult: expr.elseResult ? renameExpression(expr.elseResult, renameMap) : undefined,
      };
    case "group":
      return { ...expr, expression: renameExpression(expr.expression, renameMap) };
    case "json_literal":
      return {
        ...expr,
        entries: expr.entries.map((entry) => ({
          key: entry.key,
          value: renameExpression(entry.value, renameMap),
        })),
      };
    case "string_interp":
      return {
        ...expr,
        parts: expr.parts.map((part) => (typeof part === "string" ? part : renameExpression(part, renameMap))),
      };
    case "unary":
      return { ...expr, expression: renameExpression(expr.expression, renameMap) };
    case "literal":
    case "sql_block":
      return expr;
  }
}

function accessPayloadSql(name: string, type: string): string {
  const normalized = type.toLowerCase();
  if (normalized === "json" || normalized === "jsonb") {
    return `($1->'${sqlEscape(name)}')`;
  }
  return `($1->>'${sqlEscape(name)}')::${type}`;
}
