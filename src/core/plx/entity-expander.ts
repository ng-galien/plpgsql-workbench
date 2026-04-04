import type {
  AssignStatement,
  EntityField,
  EntityHook,
  Expression,
  FormField,
  FormSection,
  IfStatement,
  JsonLiteral,
  Loc,
  PlxEntity,
  PlxFunction,
  PlxModule,
  PlxTrait,
  ReturnStatement,
  SqlBlockExpr,
  Statement,
  StateTransition,
  StrategyDecl,
  ViewSection,
} from "./ast.js";
import { pointLoc } from "./ast.js";
import {
  assertStmt as buildAssertStmt,
  assignStmt as buildAssignStmt,
  castExpr as buildCastExpr,
  jsonObj as buildJsonObj,
  returnStmt as buildReturnStmt,
  sqlBlock as buildSqlBlock,
  identifierExpr,
  jsonEntry,
  nullLiteral,
  qualifiedIdentifierExpr,
  rawSqlExpr,
  textArray,
  textLiteral,
} from "./ast-builders.js";
import { type DdlArtifact, generateDDL, type ResolvedEntityFields } from "./entity-ddl.js";
import { formatDefaultValue } from "./entity-sql.js";
import { sqlEscape } from "./util.js";

const LOC: Loc = pointLoc();

// ---------- Public API ----------

interface ExpandResult {
  functions: PlxFunction[];
  ddlFragments: string[];
  ddlArtifacts: DdlArtifact[];
  errors: ExpandError[];
}

interface ExpandError {
  loc: Loc;
  message: string;
  entityName: string;
}

export function expandEntities(mod: PlxModule): ExpandResult {
  const traitRegistry = new Map<string, PlxTrait>();
  for (const t of mod.traits) traitRegistry.set(t.name, t);

  const functions: PlxFunction[] = [];
  const ddlFragments: string[] = [];
  const ddlArtifacts: DdlArtifact[] = [];
  const errors: ExpandError[] = [];
  const schemasWithEntities = new Set<string>();

  for (const entity of mod.entities) {
    // Resolve traits
    const resolvedFields = resolveEntityFields(entity, traitRegistry, errors);

    try {
      if (!schemasWithEntities.has(entity.schema)) {
        schemasWithEntities.add(entity.schema);
        const authArtifact = buildAuthorizeArtifact(entity.schema);
        ddlArtifacts.push(authArtifact);
        ddlFragments.push(authArtifact.sql);
      }

      functions.push(buildViewFunction(entity));
      functions.push(buildListFunction(entity));
      functions.push(buildReadFunction(entity));
      functions.push(buildCreateFunction(entity, resolvedFields));
      functions.push(buildUpdateFunction(entity, resolvedFields));
      functions.push(buildDeleteFunction(entity));
      // State transition functions
      if (entity.states) {
        for (const tr of entity.states.transitions) {
          functions.push(buildTransitionFunction(entity, tr));
        }
      }
      const entityDdl = generateDDL(entity, resolvedFields);
      ddlArtifacts.push(...entityDdl.artifacts);
      ddlFragments.push(...entityDdl.artifacts.map((artifact) => artifact.sql));
    } catch (e: unknown) {
      errors.push({
        loc: entity.loc,
        message: e instanceof Error ? e.message : String(e),
        entityName: `${entity.schema}.${entity.name}`,
      });
    }
  }

  return { functions, ddlFragments, ddlArtifacts, errors };
}

function buildAuthorizeArtifact(schema: string): DdlArtifact {
  return {
    key: `ddl:authorize-fn:${schema}`,
    name: `${schema}.authorize`,
    dependsOn: [`ddl:schema:${schema}`],
    sql: `CREATE OR REPLACE FUNCTION ${schema}.authorize(p_permission text) RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ${schema}, pg_catalog, pg_temp AS $$
DECLARE
  v_perms text := current_setting('app.permissions', true);
BEGIN
  IF v_perms IS NULL THEN
    RAISE EXCEPTION 'forbidden: no permissions configured';
  END IF;
  IF NOT p_permission = ANY(string_to_array(v_perms, ',')) THEN
    RAISE EXCEPTION 'forbidden: % denied', p_permission;
  END IF;
END;
$$;`,
  };
}

// ---------- Trait resolution ----------

function resolveEntityFields(
  entity: PlxEntity,
  registry: Map<string, PlxTrait>,
  errors: ExpandError[],
): ResolvedEntityFields {
  const traitFields: EntityField[] = [];
  for (const traitName of entity.traits) {
    const trait = registry.get(traitName);
    if (!trait) {
      // Built-in traits
      if (traitName === "auditable") {
        traitFields.push(
          fieldDef("created_at", "timestamptz", false, "now()", entity.loc),
          fieldDef("updated_at", "timestamptz", false, "now()", entity.loc),
        );
      } else if (traitName === "soft_delete") {
        traitFields.push(fieldDef("deleted_at", "timestamptz", true, undefined, entity.loc));
      } else {
        errors.push({
          loc: entity.loc,
          message: `unknown trait '${traitName}'`,
          entityName: `${entity.schema}.${entity.name}`,
        });
      }
      continue;
    }
    for (const f of trait.fields) {
      traitFields.push({ ...f, required: false, unique: false, createOnly: false, readOnly: false });
    }
  }

  if (entity.storage === "hybrid") {
    return {
      columns: [...entity.columns, ...traitFields],
      payload: [...entity.payload],
      all: [...entity.columns, ...entity.payload, ...traitFields],
    };
  }

  return {
    columns: [...entity.fields, ...traitFields],
    payload: [],
    all: [...entity.fields, ...traitFields],
  };
}

/** Returns a WHERE fragment from traits (e.g., soft_delete → "deleted_at IS NULL") */
function defaultScope(entity: PlxEntity, alias: string): string {
  const scopes: string[] = [];
  if (entity.traits.includes("soft_delete")) {
    scopes.push(`${alias}.deleted_at IS NULL`);
  }
  // Custom traits with defaultScope
  // (handled when trait registry is fully wired)
  return scopes.length > 0 ? scopes.join(" AND ") : "";
}

const TENANT_WHERE = "tenant_id = (SELECT current_setting('app.tenant_id'))";

function tenantScope(alias: string): string {
  return `${alias}.${TENANT_WHERE}`;
}

function accessScope(entity: PlxEntity, alias: string): string {
  const scopes = [tenantScope(alias)];
  const logicalScope = defaultScope(entity, alias);
  if (logicalScope) scopes.push(logicalScope);
  return scopes.join(" AND ");
}

function fieldDef(name: string, type: string, nullable: boolean, defaultValue?: string, loc: Loc = LOC): EntityField {
  return {
    name,
    type,
    nullable,
    defaultValue,
    required: false,
    unique: false,
    createOnly: false,
    readOnly: false,
    ref: undefined,
    loc,
  };
}

// ---------- Function builders ----------

function buildViewFunction(entity: PlxEntity): PlxFunction {
  const loc = entity.loc;
  const view = entity.view;
  const entries: JsonLiteral["entries"] = [
    jEntry("uri", strLit(entity.uri, loc)),
    jEntry("label", strLit(entity.label, loc)),
  ];
  if (entity.icon) entries.push(jEntry("icon", strLit(entity.icon, loc)));

  // Template
  const template: JsonLiteral["entries"] = [];
  template.push(jEntry("compact", jObj([jEntry("fields", strArr(view.compact, loc))], loc)));
  if (view.standard) template.push(jEntry("standard", buildViewSection(view.standard, loc)));
  if (view.expanded) template.push(jEntry("expanded", buildViewSection(view.expanded, loc)));
  if (view.form) template.push(jEntry("form", buildFormSections(view.form, loc)));
  entries.push(jEntry("template", jObj(template, loc)));

  // Actions catalog: explicit actions + auto-generated transition actions
  const allActions = [...entity.actions];
  if (entity.states) {
    for (const tr of entity.states.transitions) {
      // Don't duplicate if already declared explicitly
      if (!allActions.some((a) => a.name === tr.name)) {
        allActions.push({
          name: tr.name,
          label: `${entity.schema}.action_${tr.name}`,
          variant: "primary",
        });
      }
    }
  }
  if (allActions.length > 0) {
    const actionEntries = allActions.map((a) => {
      const props: JsonLiteral["entries"] = [jEntry("label", strLit(a.label, loc))];
      if (a.icon) props.push(jEntry("icon", strLit(a.icon, loc)));
      if (a.variant) props.push(jEntry("variant", strLit(a.variant, loc)));
      if (a.confirm) props.push(jEntry("confirm", strLit(a.confirm, loc)));
      return jEntry(a.name, jObj(props, loc));
    });
    entries.push(jEntry("actions", jObj(actionEntries, loc)));
  }

  const body: Statement[] = [{ kind: "return", value: jObj(entries, loc), isYield: false, mode: "value", loc }];

  return makeFn(entity, `${entity.name}_view`, [], "jsonb", ["stable"], body);
}

function buildViewSection(section: ViewSection, loc: Loc = LOC): Expression {
  const entries: JsonLiteral["entries"] = [jEntry("fields", strArr(section.fields, loc))];
  if (section.stats) {
    const statsArr = section.stats.map((s) =>
      jObj([jEntry("key", strLit(s.key, loc)), jEntry("label", strLit(s.label, loc))], loc),
    );
    entries.push(jEntry("stats", { kind: "array_literal", elements: statsArr, loc }));
  }
  if (section.related) {
    const relArr = section.related.map((r) =>
      jObj(
        [
          jEntry("entity", strLit(r.entity, loc)),
          jEntry("label", strLit(r.label, loc)),
          jEntry("filter", strLit(r.filter, loc)),
        ],
        loc,
      ),
    );
    entries.push(jEntry("related", { kind: "array_literal", elements: relArr, loc }));
  }
  return jObj(entries, loc);
}

function buildFormSections(sections: FormSection[], loc: Loc = LOC): Expression {
  const sectionObjs = sections.map((s) => {
    const fieldObjs = s.fields.map((f) => buildFormFieldObj(f, loc));
    return jObj(
      [jEntry("label", strLit(s.label, loc)), jEntry("fields", { kind: "array_literal", elements: fieldObjs, loc })],
      loc,
    );
  });
  return jObj([jEntry("sections", { kind: "array_literal", elements: sectionObjs, loc })], loc);
}

function buildFormFieldObj(f: FormField, loc: Loc = LOC): Expression {
  const entries: JsonLiteral["entries"] = [];
  for (const [key, value] of Object.entries(f.entries)) {
    if (typeof value === "boolean") {
      entries.push(jEntry(key, { kind: "literal", value, type: "boolean", loc }));
    } else if (typeof value === "object") {
      // Nested object → emit as JSON object
      const nested: JsonLiteral["entries"] = [];
      for (const [nk, nv] of Object.entries(value)) {
        nested.push(jEntry(nk, strLit(nv, loc)));
      }
      entries.push(jEntry(key, jObj(nested, loc)));
    } else if (key === "options" && value.includes(".")) {
      // Convention: options with a dot = qualified function ref (schema.fn) → emit call.
      // Plain strings (URIs like 'crm://client') pass through as string literals.
      entries.push(jEntry(key, { kind: "call", name: value, args: [], loc }));
    } else {
      entries.push(jEntry(key, strLit(value, loc)));
    }
  }
  return jObj(entries, loc);
}

function buildListFunction(entity: PlxEntity): PlxFunction {
  const loc = entity.loc;
  const strategy = findStrategy(entity, "list.query");
  const t = shortAlias(entity);
  const order = entity.listOrder;

  // With strategy: delegate entirely
  if (strategy) {
    const body: Statement[] = [
      tenantContextGuard(entity),
      authorizeGuard(entity, "read"),
      ret("query", sqlBlock(`SELECT ${strategy.fn}(p_filter)`, undefined, undefined, loc), loc),
    ];
    return makeFn(
      entity,
      `${entity.name}_list`,
      [{ name: "p_filter", type: "text", nullable: true, defaultValue: "NULL::text" }],
      "jsonb",
      ["stable", "definer"],
      body,
      true,
    );
  }

  // Default: IF p_filter IS NULL → static, ELSE → dynamic
  const scope = accessScope(entity, t);
  const whereScope = scope ? ` WHERE ${scope}` : "";
  const andScope = scope ? ` AND ${scope}` : "";
  const rowExpr = buildEntityJsonSelect(entity, t);

  const staticSql = `SELECT ${rowExpr} FROM ${entity.table} ${t}${whereScope} ORDER BY ${t}.${order}`;
  const dynamicExpr: Expression = {
    kind: "binary",
    op: "||",
    left: {
      kind: "binary",
      op: "||",
      left: strLit(`SELECT ${rowExpr} FROM ${entity.table} ${t} WHERE `, loc),
      right: {
        kind: "call",
        name: "pgv.rsql_to_where",
        args: [ident("p_filter", loc), strLit(entity.schema, loc), strLit(entity.name, loc)],
        loc,
      },
      loc,
    },
    right: strLit(`${andScope} ORDER BY ${t}.${order}`, loc),
    loc,
  };

  const ifStmt: IfStatement = {
    kind: "if",
    condition: { kind: "binary", op: "=", left: ident("p_filter", loc), right: nullLit(loc), loc },
    body: [ret("query", sqlBlock(staticSql, undefined, undefined, loc), loc)],
    elsifs: [],
    elseBody: [ret("execute", dynamicExpr, loc)],
    loc,
  };

  return makeFn(
    entity,
    `${entity.name}_list`,
    [{ name: "p_filter", type: "text", nullable: true, defaultValue: "NULL::text" }],
    "jsonb",
    ["stable", "definer"],
    [tenantContextGuard(entity), authorizeGuard(entity, "read"), ifStmt],
    true,
  );
}

function buildReadFunction(entity: PlxEntity): PlxFunction {
  const loc = entity.loc;
  const strategy = findStrategy(entity, "read.query");
  const readKey = entity.readKey ?? `${shortAlias(entity)}.id = p_id::int`;
  const t = shortAlias(entity);

  // Query part (with soft_delete scope if applicable)
  const scope = accessScope(entity, t);
  const andScope = scope ? ` AND ${scope}` : "";
  const rowExpr = buildEntityJsonSelect(entity, t);
  const querySql = strategy
    ? `(SELECT ${strategy.fn}(p_id))`
    : `(SELECT ${rowExpr} FROM ${entity.table} ${t} WHERE ${readKey}${andScope})`;

  const stmts: Statement[] = [
    tenantContextGuard(entity),
    authorizeGuard(entity, "read"),
    assign("result", sqlBlock(querySql, undefined, undefined, loc), loc),
    // IF result IS NULL THEN RETURN NULL
    {
      kind: "if",
      condition: { kind: "binary", op: "=", left: ident("result", loc), right: nullLit(loc), loc },
      body: [ret("value", nullLit(loc), loc)],
      elsifs: [],
      loc,
    } as IfStatement,
  ];

  // HATEOAS actions — read.hateoas strategy overrides entirely
  const hateoasStrategy = findStrategy(entity, "read.hateoas");
  if (hateoasStrategy) {
    stmts.push(
      ret(
        "value",
        {
          kind: "binary",
          op: "||",
          left: ident("result", loc),
          right: jObj(
            [
              jEntry("actions", {
                kind: "call",
                name: hateoasStrategy.fn,
                args: [ident("result", loc)],
                loc,
              }),
            ],
            loc,
          ),
          loc,
        },
        loc,
      ),
    );
  } else if (entity.states) {
    // State-based: extract status, build CASE with per-state actions
    stmts.push(
      assign("status", sqlBlock(`(v_result->>'${entity.states.column}')`, undefined, undefined, "text", loc), loc),
    );
    stmts.push(assign("actions", { kind: "array_literal", elements: [], loc }, loc));

    // Group transitions by from-state
    const byState = new Map<string, { name: string; from: string; to: string }[]>();
    for (const tr of entity.states.transitions) {
      const list = byState.get(tr.from) ?? [];
      list.push(tr);
      byState.set(tr.from, list);
    }

    // Also add static actions (edit, delete) to relevant states
    const hasEdit = entity.actions.some((a) => a.name === "edit");
    const hasDelete = entity.actions.some((a) => a.name === "delete");

    const arms: { pattern: Expression; body: Statement[] }[] = [];
    for (const [state, transitions] of byState) {
      const actionObjs: Expression[] = [];
      // Add edit action if entity has it and this is an editable state
      if (hasEdit && entity.updateStates?.includes(state)) {
        actionObjs.push(actionObj(entity, "edit"));
      }
      // Add transition actions
      for (const tr of transitions) {
        actionObjs.push(actionObj(entity, tr.name));
      }
      // Add delete action if entity has it and this is a deletable state
      if (hasDelete && entity.updateStates?.includes(state)) {
        actionObjs.push(actionObj(entity, "delete"));
      }
      arms.push({
        pattern: strLit(state, loc),
        body: [assign("actions", { kind: "array_literal", elements: actionObjs, loc } as Expression, loc)],
      });
    }

    // match status: arms + else: empty actions
    const matchStmt: Statement = {
      kind: "match",
      subject: ident("status", loc),
      arms,
      elseBody: [assign("actions", { kind: "array_literal", elements: [], loc } as Expression, loc)],
      loc,
    };
    stmts.push(matchStmt);

    stmts.push(
      ret(
        "value",
        {
          kind: "binary",
          op: "||",
          left: ident("result", loc),
          right: jObj([jEntry("actions", ident("actions", loc))], loc),
          loc,
        },
        loc,
      ),
    );
  } else if (entity.actions.length > 0) {
    // Static actions (no state machine)
    const actionArr = entity.actions.map((a) => actionObj(entity, a.name));
    stmts.push(
      ret(
        "value",
        {
          kind: "binary",
          op: "||",
          left: ident("result", loc),
          right: jObj([jEntry("actions", { kind: "array_literal", elements: actionArr, loc })], loc),
          loc,
        },
        loc,
      ),
    );
  } else {
    stmts.push(ret("value", ident("result", loc), loc));
  }

  return makeFn(
    entity,
    `${entity.name}_read`,
    [{ name: "p_id", type: "text", nullable: false }],
    "jsonb",
    ["stable", "definer"],
    stmts,
  );
}

function buildCreateFunction(entity: PlxEntity, resolved: ResolvedEntityFields): PlxFunction {
  const loc = entity.loc;
  // Exclude trait-injected audit fields (created_at, updated_at) — DB handles via DEFAULT
  const writableFields = resolved.columns.filter((f) => !f.readOnly && !isAuditField(f.name));
  const colNames = writableFields.map((f) => f.name);
  const colValues = writableFields.map((f) =>
    f.defaultValue ? `COALESCE(v_p_row.${f.name}, ${formatDefaultValue(f.defaultValue, f.type)})` : `v_p_row.${f.name}`,
  );

  if (entity.storage === "hybrid") {
    colNames.push("payload");
    colValues.push(buildCreatePayloadSql(entity, resolved.payload, "p_input"));
  }

  // create.enrich strategy: call enrichment function on p_row before INSERT
  const enrichStrategy = findStrategy(entity, "create.enrich");
  const enrichStmts: Statement[] = enrichStrategy
    ? [assign("p_row", { kind: "call", name: enrichStrategy.fn, args: [ident("p_row", loc)], loc }, loc)]
    : [];

  const validateStmts = getHookStatements(entity, "validate_create");
  const hookStmts = getHookStatements(entity, "before_create");

  const insertSql = `INSERT INTO ${entity.table} (${colNames.join(", ")})\n    VALUES (${colValues.join(", ")})\n    RETURNING *`;

  const stmts: Statement[] = [
    tenantContextGuard(entity),
    authorizeGuard(entity, "create"),
    ...buildPayloadValidation(entity, "p_input", { requireFields: true, forbidReadOnly: true }),
    assign(
      "p_row",
      {
        kind: "call",
        name: "jsonb_populate_record",
        args: [castExpr(nullLit(loc), qualifiedIdent(entity.table, loc), loc), ident("p_input", loc)],
        loc,
      },
      loc,
    ),
    ...validateStmts,
    ...enrichStmts,
    ...hookStmts,
    assign("result", sqlBlock(insertSql, undefined, undefined, loc), loc),
    ret("value", rawExpr(buildEntityJsonSelect(entity, "v_result"), loc), loc),
  ];

  return makeFn(
    entity,
    `${entity.name}_create`,
    [{ name: "p_input", type: "jsonb", nullable: false }],
    "jsonb",
    ["definer"],
    stmts,
  );
}

function buildUpdateFunction(entity: PlxEntity, resolved: ResolvedEntityFields): PlxFunction {
  const loc = entity.loc;
  const updatableFields = resolved.columns.filter((f) => !f.readOnly && !f.createOnly && !isAuditField(f.name));
  const setClauses = updatableFields.map((f) => `${f.name} = v_p_row.${f.name}`);

  if (entity.storage === "hybrid") {
    setClauses.push(`payload = ${buildUpdatePayloadSql(entity, resolved.payload, "p_input", "v_current.payload")}`);
  }

  // Auditable: always set updated_at = now()
  if (entity.traits.includes("auditable")) {
    setClauses.push("updated_at = now()");
  }

  const whereClause = `id = p_id::int${stateGuardWhere(entity)} AND ${TENANT_WHERE}`;
  const updateSql = `UPDATE ${entity.table} SET\n    ${setClauses.join(",\n    ")}\n    WHERE ${whereClause}\n    RETURNING *`;

  const validateStmts = getHookStatements(entity, "validate_update");
  const hookStmts = getHookStatements(entity, "before_update");
  const stmts: Statement[] = [
    tenantContextGuard(entity),
    authorizeGuard(entity, "modify"),
    ...buildPayloadValidation(entity, "p_input", { requireFields: false, forbidReadOnly: true }),
    assign(
      "current",
      sqlBlock(
        `SELECT * FROM ${entity.table} WHERE id = p_id::int AND ${TENANT_WHERE}`,
        `${entity.schema}.err_not_found`,
        entity.table,
        loc,
      ),
      loc,
    ),
    assign(
      "p_row",
      {
        kind: "call",
        name: "jsonb_populate_record",
        args: [ident("current", loc), ident("p_input", loc)],
        loc,
      },
      loc,
    ),
    ...validateStmts,
    ...hookStmts,
    assign("result", sqlBlock(updateSql, undefined, undefined, loc), loc),
    ret("value", rawExpr(buildEntityJsonSelect(entity, "v_result"), loc), loc),
  ];

  return makeFn(
    entity,
    `${entity.name}_update`,
    [
      { name: "p_id", type: "text", nullable: false },
      { name: "p_input", type: "jsonb", nullable: false },
    ],
    "jsonb",
    ["definer"],
    stmts,
  );
}

function buildDeleteFunction(entity: PlxEntity): PlxFunction {
  const loc = entity.loc;
  const isSoftDelete = entity.traits.includes("soft_delete");
  let sql: string;

  if (isSoftDelete) {
    sql = `UPDATE ${entity.table} SET deleted_at = now() WHERE id = p_id::int AND ${TENANT_WHERE} AND deleted_at IS NULL RETURNING *`;
  } else {
    sql = `DELETE FROM ${entity.table} WHERE id = p_id::int${stateGuardWhere(entity)} AND ${TENANT_WHERE} RETURNING *`;
  }

  const stmts: Statement[] = [tenantContextGuard(entity), authorizeGuard(entity, "delete")];
  const validateStmts = getHookStatements(entity, "validate_delete");

  // delete.guard strategy: fetch row, call guard (raises if invalid)
  const guardStrategy = findStrategy(entity, "delete.guard");
  if (guardStrategy || validateStmts.length > 0) {
    stmts.push(
      assign(
        "current",
        sqlBlock(
          `SELECT * FROM ${entity.table} WHERE id = p_id::int AND ${TENANT_WHERE}`,
          `${entity.schema}.err_not_found`,
          entity.table,
          loc,
        ),
        loc,
      ),
    );
  }
  if (validateStmts.length > 0) {
    stmts.push(...validateStmts);
  }
  if (guardStrategy) {
    stmts.push(assign("row", { kind: "call", name: "to_jsonb", args: [ident("current", loc)], loc }, loc));
    // Call guard — it raises if the delete should be blocked
    stmts.push({
      kind: "assign",
      target: "_",
      value: { kind: "call", name: guardStrategy.fn, args: [ident("row", loc)], loc },
      loc,
    });
  }

  stmts.push(assign("result", sqlBlock(sql, undefined, undefined, loc), loc));
  stmts.push(ret("value", rawExpr(buildEntityJsonSelect(entity, "v_result"), loc), loc));

  return makeFn(
    entity,
    `${entity.name}_delete`,
    [{ name: "p_id", type: "text", nullable: false }],
    "jsonb",
    ["definer"],
    stmts,
  );
}

function buildTransitionFunction(entity: PlxEntity, tr: StateTransition): PlxFunction {
  const loc = entity.loc;
  const states = entity.states;
  if (!states) {
    throw new Error(`transition '${tr.name}' requires entity states`);
  }
  const col = states.column;
  const updateSql = `UPDATE ${entity.table} SET ${col} = '${sqlEscape(tr.to)}' WHERE id = p_id::int AND ${TENANT_WHERE} AND ${col} = '${sqlEscape(tr.from)}' RETURNING *`;

  const stmts: Statement[] = [tenantContextGuard(entity), authorizeGuard(entity, tr.name)];

  // Optional guard
  if (tr.guard) {
    // Fetch row first for guard evaluation
    stmts.push(
      assign(
        "row",
        sqlBlock(
          `(SELECT ${buildEntityJsonSelect(entity, "t")} FROM ${entity.table} t WHERE t.id = p_id::int AND ${tenantScope("t")})`,
          undefined,
          undefined,
          loc,
        ),
        loc,
      ),
    );
    stmts.push({
      kind: "if",
      condition: { kind: "binary", op: "=", left: ident("row", loc), right: nullLit(loc), loc },
      body: [{ kind: "raise", message: `${entity.schema}.err_not_found`, loc }],
      elsifs: [],
      loc,
    } as Statement);
    // Guard check — raw SQL expression
    stmts.push({
      kind: "if",
      condition: {
        kind: "unary",
        op: "NOT",
        expression: { kind: "group", expression: sqlBlock(tr.guard, undefined, undefined, loc), loc },
        loc,
      },
      body: [{ kind: "raise", message: `${entity.schema}.err_guard_${tr.name}`, loc }],
      elsifs: [],
      loc,
    } as Statement);
  }

  // Transition body statements
  if (tr.body) stmts.push(...tr.body);

  // The UPDATE
  stmts.push(assign("result", sqlBlock(updateSql, `${entity.schema}.err_not_${tr.from}`, undefined, loc), loc));
  stmts.push(ret("value", rawExpr(buildEntityJsonSelect(entity, "v_result"), loc), loc));

  return makeFn(
    entity,
    `${entity.name}_${tr.name}`,
    [{ name: "p_id", type: "text", nullable: false }],
    "jsonb",
    ["definer"],
    stmts,
  );
}

/** Build a HATEOAS action object: {method: name, uri: entity://name/id/action} */
function actionObj(entity: PlxEntity, name: string): Expression {
  const loc = entity.loc;
  return jObj(
    [
      jEntry("method", strLit(name, loc)),
      jEntry("uri", {
        kind: "binary",
        op: "||",
        left: {
          kind: "binary",
          op: "||",
          left: strLit(`${entity.uri}/`, loc),
          right: ident("p_id", loc),
          loc,
        },
        right: strLit(`/${name}`, loc),
        loc,
      }),
    ],
    loc,
  );
}

// ---------- Helpers ----------

function makeFn(
  entity: PlxEntity,
  name: string,
  params: { name: string; type: string; nullable: boolean; defaultValue?: string }[],
  returnType: string,
  attributes: PlxFunction["attributes"],
  body: Statement[],
  setof = false,
): PlxFunction {
  const loc = entity.loc;
  return {
    kind: "function",
    visibility: entity.visibility,
    schema: entity.schema,
    name,
    params: params.map((p) => ({ ...p, loc })),
    returnType,
    setof,
    attributes,
    body,
    loc,
  };
}

const AUDIT_FIELDS = new Set(["created_at", "updated_at", "deleted_at"]);

function isAuditField(name: string): boolean {
  return AUDIT_FIELDS.has(name);
}

function findStrategy(entity: PlxEntity, slot: string): StrategyDecl | undefined {
  return entity.strategies.find((s) => s.slot === slot);
}

function getHookStatements(entity: PlxEntity, event: EntityHook["event"]): Statement[] {
  const hook = entity.hooks.find((h) => h.event === event);
  return hook ? hook.body : [];
}

function buildPayloadValidation(
  entity: PlxEntity,
  payloadName: string,
  options: { requireFields: boolean; forbidReadOnly: boolean },
): Statement[] {
  const loc = entity.loc;
  const stmts: Statement[] = [
    assertStmt(
      {
        kind: "binary",
        op: "=",
        left: { kind: "call", name: "jsonb_typeof", args: [ident(payloadName, loc)], loc },
        right: strLit("object", loc),
        loc,
      },
      `${entity.schema}.err_invalid_${entity.name}_payload`,
      loc,
    ),
  ];

  const writableFields = new Set(entity.fields.map((field) => field.name));
  const forbiddenFields = new Set<string>(["id"]);
  if (options.forbidReadOnly) {
    for (const field of entity.fields) {
      if (field.readOnly || isAuditField(field.name)) {
        forbiddenFields.add(field.name);
      }
    }
  }

  const knownFields = [...writableFields];
  if (knownFields.length > 0) {
    stmts.push(
      assertStmt(
        rawExpr(
          `NOT EXISTS (SELECT 1 FROM jsonb_object_keys(${payloadName}) AS k(key) WHERE k.key <> ALL (ARRAY[${knownFields.map((field) => `'${field}'`).join(", ")}]::text[]))`,
          loc,
        ),
        `${entity.schema}.err_unknown_${entity.name}_field`,
        loc,
      ),
    );
  }

  for (const field of forbiddenFields) {
    stmts.push(
      assertStmt(
        {
          kind: "unary",
          op: "NOT",
          expression: { kind: "call", name: "jsonb_exists", args: [ident(payloadName, loc), strLit(field, loc)], loc },
          loc,
        },
        `${entity.schema}.err_${field}_readonly`,
        loc,
      ),
    );
  }

  if (options.requireFields) {
    for (const field of entity.fields) {
      if (!field.required) continue;
      stmts.push(
        assertStmt(
          {
            kind: "binary",
            op: "AND",
            left: { kind: "call", name: "jsonb_exists", args: [ident(payloadName, loc), strLit(field.name, loc)], loc },
            right: {
              kind: "binary",
              op: "IS NOT NULL",
              left: {
                kind: "binary",
                op: "->>",
                left: ident(payloadName, loc),
                right: strLit(field.name, loc),
                loc,
              },
              right: nullLit(loc),
              loc,
            },
            loc,
          },
          `${entity.schema}.err_${field.name}_required`,
          loc,
        ),
      );
    }
  }

  return stmts;
}

function buildEntityJsonSelect(entity: PlxEntity, alias: string): string {
  if (entity.storage === "row") return `to_jsonb(${alias})`;

  const technicalEntries = [`'id', ${alias}.id`];
  for (const field of entity.columns) {
    technicalEntries.push(`'${field.name}', ${alias}.${field.name}`);
  }
  if (entity.states && !entity.columns.some((field) => field.name === entity.states?.column)) {
    technicalEntries.push(`'${entity.states.column}', ${alias}.${entity.states.column}`);
  }
  if (entity.traits.includes("auditable")) {
    technicalEntries.push(`'created_at', ${alias}.created_at`);
    technicalEntries.push(`'updated_at', ${alias}.updated_at`);
  }
  if (entity.traits.includes("soft_delete")) {
    technicalEntries.push(`'deleted_at', ${alias}.deleted_at`);
  }

  return `jsonb_build_object(${technicalEntries.join(", ")}) || jsonb_strip_nulls(COALESCE(${alias}.payload, '{}'::jsonb))`;
}

function buildCreatePayloadSql(entity: PlxEntity, payloadFields: EntityField[], payloadName: string): string {
  if (entity.storage !== "hybrid" || payloadFields.length === 0) {
    return `'{}'::jsonb`;
  }

  return `jsonb_strip_nulls(jsonb_build_object(${payloadFields
    .flatMap((field) => [
      `'${field.name}'`,
      field.defaultValue
        ? `COALESCE(${payloadName}->'${field.name}', ${toJsonValueSql(field.defaultValue, field.type)})`
        : `${payloadName}->'${field.name}'`,
    ])
    .join(", ")}))`;
}

function buildUpdatePayloadSql(
  entity: PlxEntity,
  payloadFields: EntityField[],
  patchName: string,
  currentDataExpr: string,
): string {
  if (entity.storage !== "hybrid" || payloadFields.length === 0) {
    return currentDataExpr;
  }

  const removedKeys = `array_remove(ARRAY[${payloadFields
    .map(
      (field) =>
        `CASE WHEN ${patchName} ? '${field.name}' AND ${patchName}->'${field.name}' = 'null'::jsonb THEN '${field.name}' ELSE NULL END`,
    )
    .join(", ")}], NULL)`;
  const pieces = payloadFields.map(
    (field) =>
      `CASE WHEN ${patchName} ? '${field.name}' AND ${patchName}->'${field.name}' <> 'null'::jsonb THEN jsonb_build_object('${field.name}', ${patchName}->'${field.name}') ELSE '{}'::jsonb END`,
  );
  return `(${currentDataExpr} - ${removedKeys}) || ${pieces.join(" || ")}`;
}

function toJsonValueSql(value: string, type: string): string {
  return `to_jsonb(${formatDefaultValue(value, type)}::${type})`;
}

function stateGuardWhere(entity: PlxEntity): string {
  if (!entity.updateStates || entity.updateStates.length === 0) return "";
  const states = entity.updateStates.map((s) => `'${sqlEscape(s)}'`).join(", ");
  const column = entity.states?.column ?? "status";
  return entity.updateStates.length === 1 ? ` AND ${column} = ${states}` : ` AND ${column} IN (${states})`;
}

function shortAlias(_entity: PlxEntity): string {
  return "t"; // universal alias — safe, no collision risk between entities
}

// AST builder helpers — accept optional loc to propagate entity source location
function strLit(value: string, loc: Loc = LOC): Expression {
  return textLiteral(value, loc);
}
function nullLit(loc: Loc = LOC): Expression {
  return nullLiteral(loc);
}
function ident(name: string, loc: Loc = LOC): Expression {
  return identifierExpr(name, loc);
}
function qualifiedIdent(name: string, loc: Loc = LOC): Expression {
  return qualifiedIdentifierExpr(name, loc);
}
function jObj(entries: JsonLiteral["entries"], loc: Loc = LOC): JsonLiteral {
  return buildJsonObj(entries, loc);
}
function jEntry(key: string, value: Expression): JsonLiteral["entries"][number] {
  return jsonEntry(key, value);
}
function strArr(items: string[], loc: Loc = LOC): Expression {
  return textArray(items, loc);
}
function sqlBlock(
  sql: string,
  elseRaise?: string,
  inferredTable?: string,
  inferredTypeOrLoc?: string | Loc,
  loc: Loc = LOC,
): SqlBlockExpr {
  return buildSqlBlock(sql, elseRaise, inferredTable, inferredTypeOrLoc, loc);
}
function assign(target: string, value: Expression, loc: Loc = LOC): AssignStatement {
  return buildAssignStmt(target, value, loc);
}
function ret(mode: ReturnStatement["mode"], value: Expression, loc: Loc = LOC): ReturnStatement {
  return buildReturnStmt(mode, value, loc);
}
function castExpr(left: Expression, right: Expression, loc: Loc = LOC): Expression {
  return buildCastExpr(left, right, loc);
}
function assertStmt(expression: Expression, message: string, loc: Loc = LOC): Statement {
  return buildAssertStmt(expression, message, loc);
}
function rawExpr(sql: string, loc: Loc = LOC): SqlBlockExpr {
  return rawSqlExpr(sql, loc);
}

function authorizeGuard(entity: PlxEntity, action: string): Statement {
  return {
    kind: "sql_statement",
    sql: `PERFORM ${entity.schema}.authorize('${sqlEscape(`${entity.schema}.${entity.name}.${action}`)}')`,
    loc: entity.loc,
  };
}

function tenantContextGuard(entity: PlxEntity): Statement {
  return {
    kind: "sql_statement",
    sql: `IF NULLIF(current_setting('app.tenant_id', true), '') IS NULL THEN RAISE EXCEPTION 'forbidden: no tenant context'; END IF`,
    loc: entity.loc,
  };
}
