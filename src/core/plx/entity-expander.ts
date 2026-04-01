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

const LOC: Loc = pointLoc();

// ---------- Public API ----------

export interface ExpandResult {
  functions: PlxFunction[];
  ddlFragments: string[];
  errors: ExpandError[];
}

export interface ExpandError {
  loc: Loc;
  message: string;
  entityName: string;
}

export function expandEntities(mod: PlxModule): ExpandResult {
  const traitRegistry = new Map<string, PlxTrait>();
  for (const t of mod.traits) traitRegistry.set(t.name, t);

  const functions: PlxFunction[] = [];
  const ddlFragments: string[] = [];
  const errors: ExpandError[] = [];

  for (const entity of mod.entities) {
    // Resolve traits
    const resolvedFields = resolveTraitFields(entity, traitRegistry, errors);

    try {
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
      ddlFragments.push(generateDDL(entity, resolvedFields));
    } catch (e: unknown) {
      errors.push({
        loc: entity.loc,
        message: e instanceof Error ? e.message : String(e),
        entityName: `${entity.schema}.${entity.name}`,
      });
    }
  }

  return { functions, ddlFragments, errors };
}

// ---------- Trait resolution ----------

function resolveTraitFields(entity: PlxEntity, registry: Map<string, PlxTrait>, errors: ExpandError[]): EntityField[] {
  const traitFields: EntityField[] = [];
  for (const traitName of entity.traits) {
    const trait = registry.get(traitName);
    if (!trait) {
      // Built-in traits
      if (traitName === "auditable") {
        traitFields.push(
          fieldDef("created_at", "timestamptz", false, "now()"),
          fieldDef("updated_at", "timestamptz", false, "now()"),
        );
      } else if (traitName === "soft_delete") {
        traitFields.push(fieldDef("deleted_at", "timestamptz", true));
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
  return [...entity.fields, ...traitFields];
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

function fieldDef(name: string, type: string, nullable: boolean, defaultValue?: string): EntityField {
  return {
    name,
    type,
    nullable,
    defaultValue,
    required: false,
    unique: false,
    createOnly: false,
    readOnly: false,
    loc: LOC,
  };
}

// ---------- DDL generation ----------

function generateDDL(entity: PlxEntity, allFields: EntityField[]): string {
  const lines: string[] = [];
  lines.push(`CREATE TABLE IF NOT EXISTS ${entity.table} (`);
  lines.push("  id serial PRIMARY KEY,");

  for (const f of allFields) {
    let col = `  ${f.name} ${f.type}`;
    if (!f.nullable) col += " NOT NULL";
    if (f.unique) col += " UNIQUE";
    if (f.defaultValue) col += ` DEFAULT ${formatDefaultValue(f.defaultValue, f.type)}`;
    col += ",";
    lines.push(col);
  }

  // State column CHECK constraint
  const states = entity.states;
  if (states) {
    const vals = states.values.map((v) => `'${v}'`).join(", ");
    // Add state column CHECK if not already in fields
    // Only add if status is not already in fields
    if (!allFields.some((f) => f.name === states.column)) {
      lines.push(`  ${states.column} text NOT NULL DEFAULT '${states.initial}' CHECK (${states.column} IN (${vals})),`);
    }
  }

  // Remove trailing comma from last line
  const lastLine = lines.at(-1) ?? "";
  lines[lines.length - 1] = lastLine.replace(/,$/, "");

  lines.push(");");
  lines.push("");
  lines.push(`GRANT USAGE ON SCHEMA ${entity.schema} TO anon;`);
  lines.push(`GRANT SELECT ON TABLE ${entity.table} TO anon;`);

  return lines.join("\n");
}

// ---------- Function builders ----------

function buildViewFunction(entity: PlxEntity): PlxFunction {
  const view = entity.view;
  const entries: JsonLiteral["entries"] = [jEntry("uri", strLit(entity.uri)), jEntry("label", strLit(entity.label))];
  if (entity.icon) entries.push(jEntry("icon", strLit(entity.icon)));

  // Template
  const template: JsonLiteral["entries"] = [];
  template.push(jEntry("compact", jObj([jEntry("fields", strArr(view.compact))])));
  if (view.standard) template.push(jEntry("standard", buildViewSection(view.standard)));
  if (view.expanded) template.push(jEntry("expanded", buildViewSection(view.expanded)));
  if (view.form) template.push(jEntry("form", buildFormSections(view.form)));
  entries.push(jEntry("template", jObj(template)));

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
      const props: JsonLiteral["entries"] = [jEntry("label", strLit(a.label))];
      if (a.icon) props.push(jEntry("icon", strLit(a.icon)));
      if (a.variant) props.push(jEntry("variant", strLit(a.variant)));
      if (a.confirm) props.push(jEntry("confirm", strLit(a.confirm)));
      return jEntry(a.name, jObj(props));
    });
    entries.push(jEntry("actions", jObj(actionEntries)));
  }

  const body: Statement[] = [{ kind: "return", value: jObj(entries), isYield: false, mode: "value", loc: LOC }];

  return makeFn(entity, `${entity.name}_view`, [], "jsonb", ["stable"], body);
}

function buildViewSection(section: ViewSection): Expression {
  const entries: JsonLiteral["entries"] = [jEntry("fields", strArr(section.fields))];
  if (section.stats) {
    const statsArr = section.stats.map((s) => jObj([jEntry("key", strLit(s.key)), jEntry("label", strLit(s.label))]));
    entries.push(jEntry("stats", { kind: "array_literal", elements: statsArr, loc: LOC }));
  }
  if (section.related) {
    const relArr = section.related.map((r) =>
      jObj([jEntry("entity", strLit(r.entity)), jEntry("label", strLit(r.label)), jEntry("filter", strLit(r.filter))]),
    );
    entries.push(jEntry("related", { kind: "array_literal", elements: relArr, loc: LOC }));
  }
  return jObj(entries);
}

function buildFormSections(sections: FormSection[]): Expression {
  const sectionObjs = sections.map((s) => {
    const fieldObjs = s.fields.map((f) => buildFormFieldObj(f));
    return jObj([
      jEntry("label", strLit(s.label)),
      jEntry("fields", { kind: "array_literal", elements: fieldObjs, loc: LOC }),
    ]);
  });
  return jObj([jEntry("sections", { kind: "array_literal", elements: sectionObjs, loc: LOC })]);
}

function buildFormFieldObj(f: FormField): Expression {
  const entries: JsonLiteral["entries"] = [
    jEntry("key", strLit(f.key)),
    jEntry("type", strLit(f.type)),
    jEntry("label", strLit(f.label)),
  ];
  if (f.required) entries.push(jEntry("required", { kind: "literal", value: true, type: "boolean", loc: LOC }));
  return jObj(entries);
}

function buildListFunction(entity: PlxEntity): PlxFunction {
  const strategy = findStrategy(entity, "list.query");
  const t = shortAlias(entity);
  const order = entity.listOrder;

  // With strategy: delegate entirely
  if (strategy) {
    const body: Statement[] = [ret("query", sqlBlock(`SELECT ${strategy.fn}(p_filter)`))];
    return makeFn(
      entity,
      `${entity.name}_list`,
      [{ name: "p_filter", type: "text", nullable: true, defaultValue: "NULL::text" }],
      "jsonb",
      ["stable"],
      body,
      true,
    );
  }

  // Default: IF p_filter IS NULL → static, ELSE → dynamic
  const scope = defaultScope(entity, t);
  const whereScope = scope ? ` WHERE ${scope}` : "";
  const andScope = scope ? ` AND ${scope}` : "";

  const staticSql = `SELECT to_jsonb(${t}) FROM ${entity.table} ${t}${whereScope} ORDER BY ${t}.${order}`;
  const dynamicExpr: Expression = {
    kind: "binary",
    op: "||",
    left: {
      kind: "binary",
      op: "||",
      left: strLit(`SELECT to_jsonb(${t}) FROM ${entity.table} ${t} WHERE `),
      right: {
        kind: "call",
        name: "pgv.rsql_to_where",
        args: [ident("p_filter"), strLit(entity.schema), strLit(entity.name)],
        loc: LOC,
      },
      loc: LOC,
    },
    right: strLit(`${andScope} ORDER BY ${t}.${order}`),
    loc: LOC,
  };

  const ifStmt: IfStatement = {
    kind: "if",
    condition: { kind: "binary", op: "=", left: ident("p_filter"), right: nullLit(), loc: LOC },
    body: [ret("query", sqlBlock(staticSql))],
    elsifs: [],
    elseBody: [ret("execute", dynamicExpr)],
    loc: LOC,
  };

  return makeFn(
    entity,
    `${entity.name}_list`,
    [{ name: "p_filter", type: "text", nullable: true, defaultValue: "NULL::text" }],
    "jsonb",
    ["stable"],
    [ifStmt],
    true,
  );
}

function buildReadFunction(entity: PlxEntity): PlxFunction {
  const strategy = findStrategy(entity, "read.query");
  const readKey = entity.readKey ?? `${shortAlias(entity)}.id = p_id::int`;
  const t = shortAlias(entity);

  // Query part (with soft_delete scope if applicable)
  const scope = defaultScope(entity, t);
  const andScope = scope ? ` AND ${scope}` : "";
  const querySql = strategy
    ? `(SELECT ${strategy.fn}(p_id))`
    : `(SELECT to_jsonb(${t}) FROM ${entity.table} ${t} WHERE ${readKey}${andScope})`;

  const stmts: Statement[] = [
    assign("result", sqlBlock(querySql)),
    // IF result IS NULL THEN RETURN NULL
    {
      kind: "if",
      condition: { kind: "binary", op: "=", left: ident("result"), right: nullLit(), loc: LOC },
      body: [ret("value", nullLit())],
      elsifs: [],
      loc: LOC,
    } as IfStatement,
  ];

  // HATEOAS actions — read.hateoas strategy overrides entirely
  const hateoasStrategy = findStrategy(entity, "read.hateoas");
  if (hateoasStrategy) {
    stmts.push(
      ret("value", {
        kind: "binary",
        op: "||",
        left: ident("result"),
        right: jObj([
          jEntry("actions", {
            kind: "call",
            name: hateoasStrategy.fn,
            args: [ident("result")],
            loc: LOC,
          }),
        ]),
        loc: LOC,
      }),
    );
  } else if (entity.states) {
    // State-based: extract status, build CASE with per-state actions
    stmts.push(assign("status", sqlBlock(`(v_result->>'status')`)));
    stmts.push(assign("id", sqlBlock(`(v_result->>'id')::int`)));
    stmts.push(assign("actions", { kind: "array_literal", elements: [], loc: LOC }));

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
        pattern: strLit(state),
        body: [assign("actions", { kind: "array_literal", elements: actionObjs, loc: LOC } as Expression)],
      });
    }

    // match status: arms + else: empty actions
    const matchStmt: Statement = {
      kind: "match",
      subject: ident("status"),
      arms,
      elseBody: [assign("actions", { kind: "array_literal", elements: [], loc: LOC } as Expression)],
      loc: LOC,
    };
    stmts.push(matchStmt);

    stmts.push(
      ret("value", {
        kind: "binary",
        op: "||",
        left: ident("result"),
        right: jObj([jEntry("actions", ident("actions"))]),
        loc: LOC,
      }),
    );
  } else if (entity.actions.length > 0) {
    // Static actions (no state machine)
    const actionArr = entity.actions.map((a) => actionObj(entity, a.name));
    stmts.push(
      ret("value", {
        kind: "binary",
        op: "||",
        left: ident("result"),
        right: jObj([jEntry("actions", { kind: "array_literal", elements: actionArr, loc: LOC })]),
        loc: LOC,
      }),
    );
  } else {
    stmts.push(ret("value", ident("result")));
  }

  return makeFn(
    entity,
    `${entity.name}_read`,
    [{ name: "p_id", type: "text", nullable: false }],
    "jsonb",
    ["stable"],
    stmts,
  );
}

function buildCreateFunction(entity: PlxEntity, allFields: EntityField[]): PlxFunction {
  // Exclude trait-injected audit fields (created_at, updated_at) — DB handles via DEFAULT
  const writableFields = allFields.filter((f) => !f.readOnly && !isAuditField(f.name));
  const colNames = writableFields.map((f) => f.name).join(", ");
  const colValues = writableFields
    .map((f) =>
      f.defaultValue
        ? `COALESCE(v_p_row.${f.name}, ${formatDefaultValue(f.defaultValue, f.type)})`
        : `v_p_row.${f.name}`,
    )
    .join(", ");

  // create.enrich strategy: call enrichment function on p_row before INSERT
  const enrichStrategy = findStrategy(entity, "create.enrich");
  const enrichStmts: Statement[] = enrichStrategy
    ? [assign("p_row", { kind: "call", name: enrichStrategy.fn, args: [ident("p_row")], loc: LOC })]
    : [];

  const validateStmts = getHookStatements(entity, "validate_create");
  const hookStmts = getHookStatements(entity, "before_create");

  const insertSql = `INSERT INTO ${entity.table} (${colNames})\n    VALUES (${colValues})\n    RETURNING *`;

  const stmts: Statement[] = [
    ...buildPayloadValidation(entity, "p_data", { requireFields: true, forbidReadOnly: true }),
    assign("p_row", {
      kind: "call",
      name: "jsonb_populate_record",
      args: [castExpr(nullLit(), qualifiedIdent(entity.table)), ident("p_data")],
      loc: LOC,
    }),
    ...validateStmts,
    ...enrichStmts,
    ...hookStmts,
    assign("result", sqlBlock(insertSql)),
    ret("value", { kind: "call", name: "to_jsonb", args: [ident("result")], loc: LOC }),
  ];

  return makeFn(
    entity,
    `${entity.name}_create`,
    [{ name: "p_data", type: "jsonb", nullable: false }],
    "jsonb",
    ["definer"],
    stmts,
  );
}

function buildUpdateFunction(entity: PlxEntity, allFields: EntityField[]): PlxFunction {
  const updatableFields = allFields.filter((f) => !f.readOnly && !f.createOnly && !isAuditField(f.name));
  const setClauses = updatableFields.map((f) => `${f.name} = v_p_row.${f.name}`);

  // Auditable: always set updated_at = now()
  if (entity.traits.includes("auditable")) {
    setClauses.push("updated_at = now()");
  }

  const whereClause = `id = p_id::int${stateGuardWhere(entity)}`;
  const updateSql = `UPDATE ${entity.table} SET\n    ${setClauses.join(",\n    ")}\n    WHERE ${whereClause}\n    RETURNING *`;

  const validateStmts = getHookStatements(entity, "validate_update");
  const hookStmts = getHookStatements(entity, "before_update");
  const stmts: Statement[] = [
    ...buildPayloadValidation(entity, "p_patch", { requireFields: false, forbidReadOnly: true }),
    assign(
      "current",
      sqlBlock(`SELECT * FROM ${entity.table} WHERE id = p_id::int`, `${entity.schema}.err_not_found`, entity.table),
    ),
    assign("p_row", {
      kind: "call",
      name: "jsonb_populate_record",
      args: [ident("current"), ident("p_patch")],
      loc: LOC,
    }),
    ...validateStmts,
    ...hookStmts,
    assign("result", sqlBlock(updateSql)),
    ret("value", { kind: "call", name: "to_jsonb", args: [ident("result")], loc: LOC }),
  ];

  return makeFn(
    entity,
    `${entity.name}_update`,
    [
      { name: "p_id", type: "text", nullable: false },
      { name: "p_patch", type: "jsonb", nullable: false },
    ],
    "jsonb",
    ["definer"],
    stmts,
  );
}

function buildDeleteFunction(entity: PlxEntity): PlxFunction {
  const isSoftDelete = entity.traits.includes("soft_delete");
  let sql: string;

  if (isSoftDelete) {
    sql = `UPDATE ${entity.table} SET deleted_at = now() WHERE id = p_id::int AND deleted_at IS NULL RETURNING *`;
  } else {
    sql = `DELETE FROM ${entity.table} WHERE id = p_id::int${stateGuardWhere(entity)} RETURNING *`;
  }

  const stmts: Statement[] = [];
  const validateStmts = getHookStatements(entity, "validate_delete");

  // delete.guard strategy: fetch row, call guard (raises if invalid)
  const guardStrategy = findStrategy(entity, "delete.guard");
  if (guardStrategy || validateStmts.length > 0) {
    stmts.push(
      assign(
        "current",
        sqlBlock(`SELECT * FROM ${entity.table} WHERE id = p_id::int`, `${entity.schema}.err_not_found`, entity.table),
      ),
    );
  }
  if (validateStmts.length > 0) {
    stmts.push(...validateStmts);
  }
  if (guardStrategy) {
    stmts.push(assign("row", { kind: "call", name: "to_jsonb", args: [ident("current")], loc: LOC }));
    // Call guard — it raises if the delete should be blocked
    stmts.push({
      kind: "assign",
      target: "_",
      value: { kind: "call", name: guardStrategy.fn, args: [ident("row")], loc: LOC },
      loc: LOC,
    });
  }

  stmts.push(assign("result", sqlBlock(sql)));
  stmts.push(ret("value", { kind: "call", name: "to_jsonb", args: [ident("result")], loc: LOC }));

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
  const states = entity.states;
  if (!states) {
    throw new Error(`transition '${tr.name}' requires entity states`);
  }
  const col = states.column;
  const updateSql = `UPDATE ${entity.table} SET ${col} = '${tr.to}' WHERE id = p_id::int AND ${col} = '${tr.from}' RETURNING *`;

  const stmts: Statement[] = [];

  // Optional guard
  if (tr.guard) {
    // Fetch row first for guard evaluation
    stmts.push(assign("row", sqlBlock(`(SELECT to_jsonb(t) FROM ${entity.table} t WHERE t.id = p_id::int)`)));
    stmts.push({
      kind: "if",
      condition: { kind: "binary", op: "=", left: ident("row"), right: nullLit(), loc: LOC },
      body: [{ kind: "raise", message: `${entity.schema}.err_not_found`, loc: LOC }],
      elsifs: [],
      loc: LOC,
    } as Statement);
    // Guard check — raw SQL expression
    stmts.push({
      kind: "if",
      condition: {
        kind: "binary",
        op: "NOT",
        left: { kind: "literal", value: true, type: "boolean", loc: LOC },
        right: sqlBlock(tr.guard),
        loc: LOC,
      },
      body: [{ kind: "raise", message: `${entity.schema}.err_guard_${tr.name}`, loc: LOC }],
      elsifs: [],
      loc: LOC,
    } as Statement);
  }

  // Transition body statements
  if (tr.body) stmts.push(...tr.body);

  // The UPDATE
  stmts.push(assign("result", sqlBlock(updateSql, `${entity.schema}.err_not_${tr.from}`)));
  stmts.push(ret("value", { kind: "call", name: "to_jsonb", args: [ident("result")], loc: LOC }));

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
  return jObj([
    jEntry("method", strLit(name)),
    jEntry("uri", {
      kind: "binary",
      op: "||",
      left: {
        kind: "binary",
        op: "||",
        left: strLit(`${entity.uri}/`),
        right: ident("p_id"),
        loc: LOC,
      },
      right: strLit(`/${name}`),
      loc: LOC,
    }),
  ]);
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
  return {
    kind: "function",
    visibility: entity.visibility,
    schema: entity.schema,
    name,
    params: params.map((p) => ({ ...p, loc: LOC })),
    returnType,
    setof,
    attributes,
    body,
    loc: entity.loc,
  };
}

/** Quote default values for DDL: text types need quotes, others (bool, numeric, function calls) don't. */
function formatDefaultValue(value: string, type: string): string {
  const lowerType = type.toLowerCase();
  // Already looks like SQL (function call, cast, keyword)
  if (value.includes("(") || value.includes("::") || value === "true" || value === "false" || value === "null") {
    return value;
  }
  // Numeric types: emit as-is
  if (/^(int|integer|bigint|smallint|numeric|decimal|float|double|serial|real)/.test(lowerType)) {
    return value;
  }
  // Text-like types: quote
  return `'${value.replace(/'/g, "''")}'`;
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
  const stmts: Statement[] = [
    assertStmt(
      {
        kind: "binary",
        op: "=",
        left: { kind: "call", name: "jsonb_typeof", args: [ident(payloadName)], loc: LOC },
        right: strLit("object"),
        loc: LOC,
      },
      `${entity.schema}.err_invalid_${entity.name}_payload`,
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
        ),
        `${entity.schema}.err_unknown_${entity.name}_field`,
      ),
    );
  }

  for (const field of forbiddenFields) {
    stmts.push(
      assertStmt(
        {
          kind: "unary",
          op: "NOT",
          expression: { kind: "call", name: "jsonb_exists", args: [ident(payloadName), strLit(field)], loc: LOC },
          loc: LOC,
        },
        `${entity.schema}.err_${field}_readonly`,
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
            left: { kind: "call", name: "jsonb_exists", args: [ident(payloadName), strLit(field.name)], loc: LOC },
            right: {
              kind: "binary",
              op: "IS NOT NULL",
              left: {
                kind: "binary",
                op: "->>",
                left: ident(payloadName),
                right: strLit(field.name),
                loc: LOC,
              },
              right: nullLit(),
              loc: LOC,
            },
            loc: LOC,
          },
          `${entity.schema}.err_${field.name}_required`,
        ),
      );
    }
  }

  return stmts;
}

function stateGuardWhere(entity: PlxEntity): string {
  if (!entity.updateStates || entity.updateStates.length === 0) return "";
  const states = entity.updateStates.map((s) => `'${s}'`).join(", ");
  return entity.updateStates.length === 1 ? ` AND status = ${states}` : ` AND status IN (${states})`;
}

function shortAlias(_entity: PlxEntity): string {
  return "t"; // universal alias — safe, no collision risk between entities
}

// AST builder helpers
function strLit(value: string): Expression {
  return { kind: "literal", value, type: "text", loc: LOC };
}
function nullLit(): Expression {
  return { kind: "literal", value: null, type: "null", loc: LOC };
}
function ident(name: string): Expression {
  return { kind: "identifier", name, loc: LOC };
}
function qualifiedIdent(name: string): Expression {
  const [object, field] = name.split(".");
  if (!object || !field) return ident(name);
  return { kind: "field_access", object, field, loc: LOC };
}
function jObj(entries: JsonLiteral["entries"]): JsonLiteral {
  return { kind: "json_literal", entries, loc: LOC };
}
function jEntry(key: string, value: Expression): JsonLiteral["entries"][number] {
  return { key, value };
}
function strArr(items: string[]): Expression {
  return { kind: "array_literal", elements: items.map(strLit), loc: LOC };
}
function sqlBlock(sql: string, elseRaise?: string, inferredTable?: string): SqlBlockExpr {
  return { kind: "sql_block", sql, elseRaise, inferredTable, loc: LOC };
}
function assign(target: string, value: Expression): AssignStatement {
  return { kind: "assign", target, value, loc: LOC };
}
function ret(mode: ReturnStatement["mode"], value: Expression): ReturnStatement {
  return { kind: "return", value, isYield: false, mode, loc: LOC };
}
function castExpr(left: Expression, right: Expression): Expression {
  return { kind: "binary", op: "::", left, right, loc: LOC };
}
function assertStmt(expression: Expression, message: string): Statement {
  return { kind: "assert", expression, message, loc: LOC };
}
function rawExpr(sql: string): SqlBlockExpr {
  return { kind: "sql_block", sql, loc: LOC };
}
