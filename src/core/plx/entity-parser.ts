// PLX Entity Parser — Entity-specific parsing extracted from parser.ts

import type {
  ActionDef,
  EntityChangeHandler,
  EntityChangeOperation,
  EntityEvent,
  EntityField,
  EntityHook,
  EntityHookEvent,
  FormField,
  FormSection,
  PlxEntity,
  RelatedDef,
  StatDef,
  StateBlock,
  Statement,
  StateTransition,
  StrategyDecl,
  ViewBlock,
  ViewSection,
  Visibility,
} from "./ast.js";
import { mergeLoc } from "./ast.js";
import type { ParseContext } from "./parse-context.js";
import { ParseError, parseSqlBlock } from "./parse-context.js";
import { parseCommaSeparated } from "./parser-helpers.js";

export function parseEntity(ctx: ParseContext, visibility: Visibility): PlxEntity {
  const start = ctx.loc();
  ctx.expect("ENTITY");

  // schema.name
  const schema = ctx.expect("IDENT").value;
  ctx.expect("DOT");
  const name = ctx.expect("IDENT").value;

  // Optional: uses trait1, trait2
  const traits: string[] = [];
  if (ctx.isAt("USES")) {
    ctx.advance();
    traits.push(ctx.expect("IDENT").value);
    while (ctx.isAt("COMMA")) {
      ctx.advance();
      traits.push(ctx.expect("IDENT").value);
    }
  }

  ctx.expect("COLON");
  ctx.skipNewlines();
  ctx.expect("INDENT");

  // Entity body — key-value pairs and sub-blocks
  let table = `${schema}.${name}`;
  let uri = `${schema}://${name}`;
  let icon: string | undefined;
  let label = `${schema}.entity_${name}`;
  let listOrder = "id";
  let readKey: string | undefined;
  const fields: EntityField[] = [];
  const columns: EntityField[] = [];
  const payload: EntityField[] = [];
  const events: EntityEvent[] = [];
  let states: StateBlock | undefined;
  let updateStates: string[] | undefined;
  let view: ViewBlock = { compact: [] };
  const actions: ActionDef[] = [];
  const strategies: StrategyDecl[] = [];
  const hooks: EntityHook[] = [];
  const changeHandlers: EntityChangeHandler[] = [];

  while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
    ctx.skipNewlines();
    if (ctx.isAt("DEDENT") || ctx.isAt("EOF")) break;

    const kw = ctx.peek().value;

    if (kw === "table") {
      ctx.advance();
      ctx.expect("COLON");
      table = ctx.parseQualifiedName();
    } else if (kw === "uri") {
      ctx.advance();
      ctx.expect("COLON");
      uri = ctx.expect("STRING").value;
    } else if (kw === "icon") {
      ctx.advance();
      ctx.expect("COLON");
      icon = ctx.expect("STRING").value;
    } else if (kw === "label") {
      ctx.advance();
      ctx.expect("COLON");
      label = ctx.expect("STRING").value;
    } else if (kw === "list_order") {
      ctx.advance();
      ctx.expect("COLON");
      listOrder = ctx.expect("STRING").value;
    } else if (kw === "read_key") {
      ctx.advance();
      ctx.expect("COLON");
      readKey = ctx.expect("STRING").value;
    } else if (kw === "fields" || kw === "columns" || kw === "payload") {
      ctx.advance();
      ctx.expect("COLON");
      ctx.skipNewlines();
      ctx.expect("INDENT");
      const target = kw === "columns" ? columns : kw === "payload" ? payload : fields;
      while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
        ctx.skipNewlines();
        if (ctx.isAt("DEDENT")) break;
        target.push(parseEntityField(ctx));
        ctx.skipNewlines();
      }
      ctx.expect("DEDENT");
    } else if (kw === "states") {
      states = parseStateBlock(ctx);
    } else if (kw === "update_states") {
      ctx.advance();
      ctx.expect("COLON");
      ctx.expect("LBRACKET");
      updateStates = [];
      while (!ctx.isAt("RBRACKET") && !ctx.isAt("EOF")) {
        updateStates.push(ctx.expect("IDENT").value);
        if (ctx.isAt("COMMA")) ctx.advance();
      }
      ctx.expect("RBRACKET");
    } else if (kw === "view") {
      view = parseViewBlock(ctx);
    } else if (kw === "actions") {
      ctx.advance();
      ctx.expect("COLON");
      ctx.skipNewlines();
      ctx.expect("INDENT");
      while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
        ctx.skipNewlines();
        if (ctx.isAt("DEDENT")) break;
        actions.push(parseActionDef(ctx));
        ctx.skipNewlines();
      }
      ctx.expect("DEDENT");
    } else if (kw === "event") {
      events.push(parseEntityEvent(ctx, visibility));
    } else if (kw === "strategies") {
      ctx.advance();
      ctx.expect("COLON");
      ctx.skipNewlines();
      ctx.expect("INDENT");
      while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
        ctx.skipNewlines();
        if (ctx.isAt("DEDENT")) break;
        strategies.push(parseStrategyDecl(ctx));
        ctx.skipNewlines();
      }
      ctx.expect("DEDENT");
    } else if (kw === "on") {
      changeHandlers.push(parseEntityChangeHandler(ctx));
    } else if (kw === "before" || kw === "after") {
      hooks.push(parseEntityHook(ctx));
    } else if (kw === "validate") {
      hooks.push(...parseValidateBlock(ctx));
    } else {
      // Unknown key — skip line
      ctx.advance();
    }
    ctx.skipNewlines();
  }

  const end = ctx.expect("DEDENT");
  if (fields.length > 0 && (columns.length > 0 || payload.length > 0)) {
    throw new ParseError("entity cannot mix fields: with columns:/payload:", start);
  }
  const hybrid = payload.length > 0;
  const rowFields = columns.length > 0 ? columns : fields;

  return {
    kind: "entity",
    visibility,
    schema,
    name,
    table,
    uri,
    icon,
    label,
    traits,
    storage: hybrid ? "hybrid" : "row",
    columns: hybrid ? columns : rowFields,
    payload: hybrid ? payload : [],
    fields: hybrid ? [...columns, ...payload] : rowFields,
    states,
    updateStates,
    view,
    events,
    actions,
    strategies,
    hooks,
    changeHandlers,
    listOrder,
    readKey,
    loc: mergeLoc(start, end),
  };
}

// ---------- Entity sub-parsers ----------

function parseEntityField(ctx: ParseContext): EntityField {
  const loc = ctx.loc();
  const name = ctx.expect("IDENT").value;
  const type = ctx.parseQualifiedName();

  let nullable = false;
  let required = false;
  let unique = false;
  let createOnly = false;
  let readOnly = false;
  let defaultValue: string | undefined;
  let ref: string | undefined;

  // Parse modifiers: required, unique, create_only, read_only, default(...)
  while (ctx.isAt("IDENT") || ctx.isAt("QUESTION")) {
    if (ctx.isAt("QUESTION")) {
      ctx.advance();
      nullable = true;
      continue;
    }
    const mod = ctx.peek().value;
    if (mod === "required") {
      ctx.advance();
      required = true;
    } else if (mod === "unique") {
      ctx.advance();
      unique = true;
    } else if (mod === "create_only") {
      ctx.advance();
      createOnly = true;
    } else if (mod === "read_only") {
      ctx.advance();
      readOnly = true;
    } else if (mod === "default") {
      ctx.advance();
      ctx.expect("LPAREN");
      let expr = "";
      let depth = 1;
      while (depth > 0 && !ctx.isAt("EOF")) {
        const t = ctx.advance();
        if (t.type === "LPAREN") depth++;
        else if (t.type === "RPAREN") {
          depth--;
          if (depth === 0) break;
        }
        expr += (expr ? " " : "") + t.value;
      }
      defaultValue = expr;
    } else if (mod === "ref") {
      ctx.advance();
      ctx.expect("LPAREN");
      ref = ctx.parseQualifiedName();
      ctx.expect("RPAREN");
    } else {
      break;
    }
  }

  return { name, type, nullable, required, unique, createOnly, readOnly, defaultValue, ref, loc };
}

function parseStateBlock(ctx: ParseContext): StateBlock {
  const start = ctx.loc();
  ctx.advance(); // "states"

  // Parse state values: draft -> submitted -> validated -> reimbursed
  const values: string[] = [];
  values.push(ctx.expect("IDENT").value);
  while (ctx.isAt("ARROW")) {
    ctx.advance();
    values.push(ctx.expect("IDENT").value);
  }

  ctx.expect("COLON");
  ctx.skipNewlines();
  ctx.expect("INDENT");

  let column = "status";
  const transitions: StateTransition[] = [];
  while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
    ctx.skipNewlines();
    if (ctx.isAt("DEDENT")) break;

    if (ctx.peek().value === "column") {
      ctx.advance();
      ctx.expect("COLON");
      column = ctx.expect("IDENT").value;
      ctx.skipNewlines();
      continue;
    }

    const trLoc = ctx.loc();
    const trName = ctx.expect("IDENT").value;
    ctx.expect("LPAREN");
    const from = ctx.expect("IDENT").value;
    ctx.expect("ARROW");
    const to = ctx.expect("IDENT").value;
    ctx.expect("RPAREN");

    let guard: string | undefined;
    let body: Statement[] | undefined;

    // Optional colon + indent for guard/body
    if (ctx.isAt("COLON")) {
      ctx.advance();
      ctx.skipNewlines();
      ctx.expect("INDENT");
      while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
        ctx.skipNewlines();
        if (ctx.isAt("DEDENT")) break;
        if (ctx.peek().value === "guard") {
          ctx.advance();
          ctx.expect("COLON");
          if (ctx.isAt("SQL_BLOCK")) {
            guard = ctx.advance().value;
          } else {
            let guardExpr = "";
            while (!ctx.isAt("NEWLINE") && !ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
              const token = ctx.advance();
              const fragment = token.type === "STRING" ? `'${token.value.replace(/'/g, "''")}'` : token.value;
              guardExpr += (guardExpr ? " " : "") + fragment;
            }
            guard = guardExpr;
          }
        } else {
          // Body statement
          if (!body) body = [];
          body.push(ctx.parseStatement());
        }
        ctx.skipNewlines();
      }
      ctx.expect("DEDENT");
    }

    transitions.push({ name: trName, from, to, guard, body, loc: trLoc });
    ctx.skipNewlines();
  }

  const end = ctx.expect("DEDENT");
  const initial = values[0] ?? "";

  return { column, initial, values, transitions, loc: mergeLoc(start, end) };
}

function parseViewBlock(ctx: ParseContext): ViewBlock {
  ctx.advance(); // "view"
  ctx.expect("COLON");
  ctx.skipNewlines();
  ctx.expect("INDENT");

  let compact: string[] = [];
  let standard: ViewSection | undefined;
  let expanded: ViewSection | undefined;
  let form: FormSection[] | undefined;

  while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
    ctx.skipNewlines();
    if (ctx.isAt("DEDENT")) break;
    const kw = ctx.peek().value;

    if (kw === "compact") {
      ctx.advance();
      ctx.expect("COLON");
      compact = parseStringList(ctx);
    } else if (kw === "standard") {
      ctx.advance();
      ctx.expect("COLON");
      standard = parseViewSection(ctx);
    } else if (kw === "expanded") {
      ctx.advance();
      ctx.expect("COLON");
      expanded = parseViewSection(ctx);
    } else if (kw === "form") {
      ctx.advance();
      ctx.expect("COLON");
      form = parseFormSections(ctx);
    } else {
      ctx.advance(); // skip unknown
    }
    ctx.skipNewlines();
  }

  ctx.expect("DEDENT");
  return { compact, standard, expanded, form };
}

/** Parse [ident, ident, ...] as string names (NOT as PLX expressions) */
function parseStringList(ctx: ParseContext): string[] {
  ctx.expect("LBRACKET");
  ctx.skipExprWs();
  const items: string[] = [];
  while (!ctx.isAt("RBRACKET") && !ctx.isAt("EOF")) {
    // Accept ident or {key: ...} object as string
    if (ctx.isAt("IDENT")) {
      items.push(ctx.advance().value);
    } else if (ctx.isAt("LBRACE")) {
      // Skip complex field objects in compact — just capture the key
      ctx.advance();
      while (!ctx.isAt("RBRACE") && !ctx.isAt("EOF")) ctx.advance();
      ctx.expect("RBRACE");
    }
    ctx.skipExprWs();
    if (ctx.isAt("COMMA")) {
      ctx.advance();
      ctx.skipExprWs();
    }
  }
  ctx.expect("RBRACKET");
  return items;
}

function parseViewSection(ctx: ParseContext): ViewSection {
  ctx.skipNewlines();
  // Can be inline [fields] or indented block with fields/stats/related
  if (ctx.isAt("LBRACKET")) {
    return { fields: parseStringList(ctx) };
  }

  ctx.expect("INDENT");
  let fields: string[] = [];
  let stats: StatDef[] | undefined;
  let related: RelatedDef[] | undefined;

  while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
    ctx.skipNewlines();
    if (ctx.isAt("DEDENT")) break;
    const kw = ctx.peek().value;

    if (kw === "fields") {
      ctx.advance();
      ctx.expect("COLON");
      fields = parseStringList(ctx);
    } else if (kw === "stats") {
      ctx.advance();
      ctx.expect("COLON");
      stats = parseStatDefs(ctx);
    } else if (kw === "related") {
      ctx.advance();
      ctx.expect("COLON");
      related = parseRelatedDefs(ctx);
    } else {
      ctx.advance();
    }
    ctx.skipNewlines();
  }
  ctx.expect("DEDENT");
  return { fields, stats, related };
}

function parseStatDefs(ctx: ParseContext): StatDef[] {
  ctx.skipNewlines();
  ctx.expect("INDENT");
  const defs: StatDef[] = [];
  while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
    ctx.skipNewlines();
    if (ctx.isAt("DEDENT")) break;
    // {key: x, label: y}
    ctx.expect("LBRACE");
    let key = "";
    let label = "";
    while (!ctx.isAt("RBRACE") && !ctx.isAt("EOF")) {
      const k = ctx.expect("IDENT").value;
      ctx.expect("COLON");
      const v = ctx.parseQualifiedValue();
      if (k === "key") key = v;
      else if (k === "label") label = v;
      if (ctx.isAt("COMMA")) ctx.advance();
    }
    ctx.expect("RBRACE");
    defs.push({ key, label });
    ctx.skipNewlines();
  }
  ctx.expect("DEDENT");
  return defs;
}

function parseRelatedDefs(ctx: ParseContext): RelatedDef[] {
  ctx.skipNewlines();
  ctx.expect("INDENT");
  const defs: RelatedDef[] = [];
  while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
    ctx.skipNewlines();
    if (ctx.isAt("DEDENT")) break;
    ctx.expect("LBRACE");
    let entity = "";
    let label = "";
    let filter = "";
    while (!ctx.isAt("RBRACE") && !ctx.isAt("EOF")) {
      const k = ctx.expect("IDENT").value;
      ctx.expect("COLON");
      const v = ctx.expect("IDENT", "STRING").value;
      if (k === "entity") entity = v;
      else if (k === "label") label = v;
      else if (k === "filter") filter = v;
      if (ctx.isAt("COMMA")) ctx.advance();
    }
    ctx.expect("RBRACE");
    defs.push({ entity, label, filter });
    ctx.skipNewlines();
  }
  ctx.expect("DEDENT");
  return defs;
}

function parseFormSections(ctx: ParseContext): FormSection[] {
  ctx.skipNewlines();
  ctx.expect("INDENT");
  const sections: FormSection[] = [];
  while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
    ctx.skipNewlines();
    if (ctx.isAt("DEDENT")) break;
    // "section.label":
    const label = ctx.expect("STRING").value;
    ctx.expect("COLON");
    ctx.skipNewlines();
    ctx.expect("INDENT");
    const fields: FormField[] = [];
    while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
      ctx.skipNewlines();
      if (ctx.isAt("DEDENT")) break;
      fields.push(parseFormField(ctx));
      ctx.skipNewlines();
    }
    ctx.expect("DEDENT");
    sections.push({ label, fields });
    ctx.skipNewlines();
  }
  ctx.expect("DEDENT");
  return sections;
}

function parseFormField(ctx: ParseContext): FormField {
  ctx.expect("LBRACE");
  ctx.skipExprWs();
  let key = "";
  let type = "text";
  let label = "";
  let required: boolean | undefined;
  while (!ctx.isAt("RBRACE") && !ctx.isAt("EOF")) {
    const k = ctx.expect("IDENT").value;
    ctx.expect("COLON");
    if (k === "required") {
      // boolean value
      const v = ctx.advance().value;
      required = v === "true";
    } else {
      const v = ctx.parseQualifiedValue();
      if (k === "key") key = v;
      else if (k === "type") type = v;
      else if (k === "label") label = v;
    }
    ctx.skipExprWs();
    if (ctx.isAt("COMMA")) {
      ctx.advance();
      ctx.skipExprWs();
    }
  }
  ctx.expect("RBRACE");
  return { key, type, label, required };
}

function parseActionDef(ctx: ParseContext): ActionDef {
  const name = ctx.expect("IDENT").value;
  ctx.expect("COLON");
  ctx.expect("LBRACE");
  ctx.skipExprWs();
  let label = "";
  let icon: string | undefined;
  let variant: string | undefined;
  let confirm: string | undefined;
  while (!ctx.isAt("RBRACE") && !ctx.isAt("EOF")) {
    const k = ctx.expect("IDENT").value;
    ctx.expect("COLON");
    const v = ctx.parseQualifiedValue();
    if (k === "label") label = v;
    else if (k === "icon") icon = v;
    else if (k === "variant") variant = v;
    else if (k === "confirm") confirm = v;
    ctx.skipExprWs();
    if (ctx.isAt("COMMA")) {
      ctx.advance();
      ctx.skipExprWs();
    }
  }
  ctx.expect("RBRACE");
  return { name, label, icon, variant, confirm };
}

function parseStrategyDecl(ctx: ParseContext): StrategyDecl {
  const loc = ctx.loc();
  const slot = ctx.parseQualifiedName();
  ctx.expect("COLON");
  const fn = ctx.parseQualifiedName();
  return { slot, fn, loc };
}

function parseEntityEvent(ctx: ParseContext, visibility: Visibility): EntityEvent {
  const loc = ctx.loc();
  ctx.expect("IDENT"); // event
  const name = ctx.expect("IDENT").value;
  ctx.expect("LPAREN");
  const params = parseEventParams(ctx);
  ctx.expect("RPAREN");
  return { name, params, visibility, loc };
}

function parseEventParams(ctx: ParseContext): EntityEvent["params"] {
  return parseCommaSeparated(ctx, "RPAREN", () => parseEventParam(ctx));
}

function parseEventParam(ctx: ParseContext): EntityEvent["params"][number] {
  const loc = ctx.loc();
  const name = ctx.expect("IDENT").value;
  const type = ctx.parseQualifiedName();
  let nullable = false;
  if (ctx.isAt("QUESTION")) {
    ctx.advance();
    nullable = true;
  }
  return { name, type, nullable, loc };
}

function parseEntityChangeHandler(ctx: ParseContext): EntityChangeHandler {
  const start = ctx.loc();
  ctx.expect("IDENT"); // on
  const rawOp = ctx.expect("IDENT").value;
  if (rawOp !== "insert" && rawOp !== "update" && rawOp !== "delete") {
    throw new ParseError(`unsupported entity change hook '${rawOp}'`, start, {
      code: "parse.invalid-entity-change-hook",
      hint: "Use `on insert`, `on update`, or `on delete` inside entity declarations.",
    });
  }
  const op: EntityChangeOperation = rawOp;
  ctx.expect("LPAREN");
  const params: string[] = [];
  if (!ctx.isAt("RPAREN")) {
    params.push(ctx.expect("IDENT").value);
    while (ctx.isAt("COMMA")) {
      ctx.advance();
      params.push(ctx.expect("IDENT").value);
    }
  }
  ctx.expect("RPAREN");
  ctx.expect("COLON");
  ctx.skipNewlines();
  ctx.expect("INDENT");
  const body = ctx.parseBlock();
  const end = ctx.expect("DEDENT");
  return { operation: op, params, body, loc: mergeLoc(start, end) };
}

function parseValidateBlock(ctx: ParseContext): EntityHook[] {
  const start = ctx.loc();
  ctx.advance(); // validate
  ctx.expect("COLON");
  ctx.skipNewlines();
  ctx.expect("INDENT");

  const body: Statement[] = [];
  while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
    ctx.skipNewlines();
    if (ctx.isAt("DEDENT")) break;

    const ruleLoc = ctx.loc();
    const ruleName = ctx.expect("IDENT").value;
    ctx.expect("COLON");
    const expression = ctx.isAt("SQL_BLOCK") ? parseSqlBlock(ctx.advance()) : ctx.parseExpression();
    body.push({ kind: "assert", expression, message: ruleName, loc: mergeLoc(ruleLoc, expression.loc) });
    ctx.skipNewlines();
  }

  const end = ctx.expect("DEDENT");
  const loc = mergeLoc(start, end);
  return [
    { event: "validate_create", params: [], body, loc },
    { event: "validate_update", params: [], body, loc },
  ];
}

const VALID_HOOK_EVENTS: Record<string, EntityHookEvent> = {
  before_create: "before_create",
  after_create: "after_create",
  before_update: "before_update",
  after_update: "after_update",
  validate_create: "validate_create",
  validate_update: "validate_update",
  validate_delete: "validate_delete",
};

function parseEntityHook(ctx: ParseContext): EntityHook {
  const loc = ctx.loc();
  const event = ctx.advance().value; // "before", "after", "validate"
  const action = ctx.expect("IDENT").value; // "create", "update", "delete"
  if (!["create", "update", "delete"].includes(action)) {
    throw new ParseError(`unsupported entity hook action '${action}'`, ctx.loc(), {
      code: "parse.invalid-entity-hook-action",
      hint: "Use create, update, or delete after before/after/validate.",
    });
  }
  if ((event === "after" || event === "before") && action === "delete") {
    throw new ParseError(`${event} delete hooks are not supported`, ctx.loc(), {
      code: "parse.invalid-entity-hook-action",
      hint: "Use validate delete instead.",
    });
  }
  const hookEventKey = `${event}_${action}`;
  const hookEvent = VALID_HOOK_EVENTS[hookEventKey];
  if (!hookEvent) {
    throw new ParseError(`unsupported entity hook '${hookEventKey}'`, loc, {
      code: "parse.invalid-entity-hook-event",
      hint: `Valid hooks: ${Object.keys(VALID_HOOK_EVENTS).join(", ")}.`,
    });
  }

  // Optional params: (p_row)
  const params: string[] = [];
  if (event !== "validate" && ctx.isAt("LPAREN")) {
    ctx.advance();
    while (!ctx.isAt("RPAREN") && !ctx.isAt("EOF")) {
      params.push(ctx.expect("IDENT").value);
      if (ctx.isAt("COMMA")) ctx.advance();
    }
    ctx.expect("RPAREN");
  }

  ctx.expect("COLON");
  ctx.skipNewlines();
  ctx.expect("INDENT");
  const body = ctx.parseBlock();
  ctx.expect("DEDENT");

  return { event: hookEvent, params, body, loc };
}
