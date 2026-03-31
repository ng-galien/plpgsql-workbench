// PLX Parser — Slim orchestrator (top-level parsing, delegates to parse-context + entity-parser)

import type { FuncAttribute, ImportAlias, Param, PlxEntity, PlxFunction, PlxModule, PlxTest, PlxTrait } from "./ast.js";
import { mergeLoc, pointLoc } from "./ast.js";
import { parseEntity } from "./entity-parser.js";
import type { Token } from "./lexer.js";
import { ParseContext, ParseError } from "./parse-context.js";
import { sqlEscape } from "./util.js";

const VALID_FUNC_ATTRS = new Set(["stable", "immutable", "volatile", "definer", "strict"]);

export function parse(tokens: Token[]): PlxModule {
  const ctx = new ParseContext(tokens);
  return parseProgram(ctx);
}

function parseProgram(ctx: ParseContext): PlxModule {
  const imports: ImportAlias[] = [];
  const functions: PlxFunction[] = [];
  ctx.skipNewlines();

  // Parse imports at top of file
  while (ctx.isAt("IMPORT")) {
    imports.push(parseImport(ctx));
    ctx.skipNewlines();
  }

  const traits: PlxTrait[] = [];
  const entities: PlxEntity[] = [];
  const tests: PlxTest[] = [];

  while (!ctx.isAt("EOF")) {
    if (ctx.isAt("TRAIT")) {
      traits.push(parseTrait(ctx));
    } else if (ctx.isAt("ENTITY")) {
      entities.push(parseEntity(ctx));
    } else if (ctx.isAt("TEST")) {
      tests.push(parseTest(ctx));
    } else {
      functions.push(parseFunction(ctx));
    }
    ctx.skipNewlines();
  }
  return { imports, traits, entities, functions, tests };
}

/** import original as alias */
function parseImport(ctx: ParseContext): ImportAlias {
  const start = ctx.loc();
  ctx.expect("IMPORT");
  const original = ctx.parseQualifiedName();
  ctx.expect("AS");
  const aliasTok = ctx.expect("IDENT");
  ctx.skipNewlines();
  return { original, alias: aliasTok.value, loc: mergeLoc(start, aliasTok) };
}

// ---------- Trait parsing ----------

function parseTrait(ctx: ParseContext): PlxTrait {
  const start = ctx.loc();
  ctx.expect("TRAIT");
  const name = ctx.expect("IDENT").value;
  ctx.expect("COLON");
  ctx.skipNewlines();
  ctx.expect("INDENT");

  const fields: PlxTrait["fields"] = [];
  const hooks: PlxTrait["hooks"] = [];
  let defaultScope: string | undefined;

  while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
    ctx.skipNewlines();
    if (ctx.isAt("DEDENT")) break;
    const kw = ctx.peek().value;

    if (kw === "fields") {
      ctx.advance();
      ctx.expect("COLON");
      ctx.skipNewlines();
      ctx.expect("INDENT");
      while (!ctx.isAt("DEDENT") && !ctx.isAt("EOF")) {
        ctx.skipNewlines();
        if (ctx.isAt("DEDENT")) break;
        fields.push(parseFieldDef(ctx));
        ctx.skipNewlines();
      }
      ctx.expect("DEDENT");
    } else if (kw === "default_scope") {
      ctx.advance();
      ctx.expect("COLON");
      defaultScope = ctx.expect("IDENT", "STRING").value;
      ctx.skipNewlines();
    } else {
      // Skip unknown for now
      ctx.advance();
      ctx.skipNewlines();
    }
  }

  const end = ctx.expect("DEDENT");
  return { kind: "trait", name, fields, hooks, defaultScope, loc: mergeLoc(start, end) };
}

function parseFieldDef(ctx: ParseContext): PlxTrait["fields"][number] {
  const loc = ctx.loc();
  const name = ctx.expect("IDENT").value;
  const type = ctx.parseQualifiedName();
  let nullable = false;
  if (ctx.isAt("QUESTION")) {
    ctx.advance();
    nullable = true;
  }
  let defaultValue: string | undefined;
  if (ctx.isAt("IDENT") && ctx.peek().value === "default") {
    ctx.advance();
    ctx.expect("LPAREN");
    // Collect default expression tokens until )
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
  }
  return { name, type, nullable, defaultValue, loc };
}

// ---------- Function parsing ----------

function parseFunction(ctx: ParseContext): PlxFunction {
  const start = ctx.loc();
  ctx.expect("FN");

  // Accept keywords as schema/function names (e.g. fn test.something())
  const firstName = ctx.expect("IDENT", "TEST", "ASSERT").value;
  ctx.expect("DOT");
  const funcName = ctx.expect("IDENT", "TEST", "ASSERT").value;

  ctx.expect("LPAREN");
  const params = parseParams(ctx);
  ctx.expect("RPAREN");

  ctx.expect("ARROW");
  let setof = false;
  if (ctx.isAt("SETOF")) {
    ctx.advance();
    setof = true;
  }
  const returnType = parseType(ctx);

  // Optional attributes: [stable, definer]
  const attributes: FuncAttribute[] = [];
  if (ctx.isAt("LBRACKET")) {
    ctx.advance();
    while (!ctx.isAt("RBRACKET") && !ctx.isAt("EOF")) {
      const tok = ctx.expect("IDENT");
      const attr = tok.value.toLowerCase();
      if (!VALID_FUNC_ATTRS.has(attr)) {
        throw new ParseError(
          `unknown function attribute '${attr}' (valid: ${[...VALID_FUNC_ATTRS].join(", ")})`,
          pointLoc(tok.line, tok.col),
          {
            code: "parse.unknown-function-attribute",
            hint: `Use one of: ${[...VALID_FUNC_ATTRS].join(", ")}.`,
          },
        );
      }
      attributes.push(attr as FuncAttribute);
      if (ctx.isAt("COMMA")) ctx.advance();
    }
    ctx.expect("RBRACKET");
  }

  ctx.expect("COLON");
  ctx.skipNewlines();
  ctx.expect("INDENT");
  const body = ctx.parseBlock();
  const end = ctx.expect("DEDENT");

  return {
    kind: "function",
    schema: firstName,
    name: funcName,
    params,
    returnType,
    setof,
    attributes,
    body,
    loc: mergeLoc(start, end),
  };
}

function parseParams(ctx: ParseContext): Param[] {
  const params: Param[] = [];
  if (ctx.isAt("RPAREN")) return params;

  params.push(parseParam(ctx));
  while (ctx.isAt("COMMA")) {
    ctx.advance();
    params.push(parseParam(ctx));
  }
  return params;
}

function parseParam(ctx: ParseContext): Param {
  const start = ctx.loc();
  const name = ctx.expect("IDENT").value;
  const type = parseType(ctx);
  let nullable = false;
  if (ctx.isAt("QUESTION")) {
    ctx.advance();
    nullable = true;
  }
  let defaultValue: string | undefined;
  if (ctx.isAt("OPERATOR") && ctx.peek().value === "=") {
    ctx.advance();
    const tok = ctx.peek();
    if (tok.type === "STRING") {
      ctx.advance();
      defaultValue = `'${sqlEscape(tok.value)}'`;
    } else if (tok.type === "NUMBER") {
      ctx.advance();
      defaultValue = tok.value;
    } else if (tok.type === "IDENT") {
      ctx.advance();
      // null -> NULL, null on nullable type -> NULL::type
      if (tok.value === "null") {
        defaultValue = nullable ? `NULL::${type}` : "NULL";
      } else {
        defaultValue = tok.value;
      }
    }
  }
  return { name, type, nullable, defaultValue, loc: start };
}

function parseType(ctx: ParseContext): string {
  let type = ctx.parseQualifiedName();
  if (ctx.isAt("LBRACKET") && ctx.peekAt(1)?.type === "RBRACKET") {
    ctx.advance();
    ctx.advance();
    type += "[]";
  }
  return type;
}

// ---------- Test parsing ----------

function parseTest(ctx: ParseContext): PlxTest {
  const start = ctx.loc();
  ctx.expect("TEST");
  const name = ctx.expect("STRING").value;
  ctx.expect("COLON");
  ctx.skipNewlines();
  ctx.expect("INDENT");
  const body = ctx.parseBlock();
  const end = ctx.expect("DEDENT");
  return { kind: "test", name, body, loc: mergeLoc(start, end) };
}
