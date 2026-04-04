// PLX Parser — Slim orchestrator (top-level parsing, delegates to parse-context + entity-parser)

import type {
  FuncAttribute,
  ImportAlias,
  ModuleDependency,
  ModuleExport,
  ModuleInclude,
  Param,
  PlxEntity,
  PlxFunction,
  PlxModule,
  PlxSubscription,
  PlxTest,
  PlxTrait,
  Visibility,
} from "./ast.js";
import { mergeLoc, pointLoc } from "./ast.js";
import { parseEntity } from "./entity-parser.js";
import type { Token } from "./lexer.js";
import { ParseContext, ParseError } from "./parse-context.js";
import { parseCommaSeparated } from "./parser-helpers.js";
import { sqlEscape } from "./util.js";

const VALID_FUNC_ATTRS = new Set(["stable", "immutable", "volatile", "definer", "strict"]);

interface ParseOptions {
  kind?: "module" | "fragment";
}

export function parse(tokens: Token[], options: ParseOptions = {}): PlxModule {
  const ctx = new ParseContext(tokens);
  return parseProgram(ctx, options);
}

function parseProgram(ctx: ParseContext, options: ParseOptions): PlxModule {
  const kind = options.kind ?? "module";
  let moduleName: string | undefined;
  let moduleLoc: PlxModule["moduleLoc"];
  let depends: ModuleDependency[] = [];
  const exports: ModuleExport[] = [];
  const includes: ModuleInclude[] = [];
  const imports: ImportAlias[] = [];
  const functions: PlxFunction[] = [];
  ctx.skipNewlines();

  if (kind === "module" && ctx.isAt("MODULE")) {
    const parsedModule = parseModuleDecl(ctx);
    moduleName = parsedModule.name;
    moduleLoc = parsedModule.loc;
    ctx.skipNewlines();
  }

  if (kind === "module" && ctx.isAt("DEPENDS")) {
    if (!moduleName) {
      throw new ParseError("depends requires a preceding module declaration", ctx.loc(), {
        code: "parse.depends-without-module",
        hint: "Declare `module <name>` before listing dependencies.",
      });
    }
    depends = parseDepends(ctx);
    ctx.skipNewlines();
  }

  const traits: PlxTrait[] = [];
  const entities: PlxEntity[] = [];
  const subscriptions: PlxSubscription[] = [];
  const tests: PlxTest[] = [];

  while (!ctx.isAt("EOF")) {
    if (ctx.isAt("IMPORT")) {
      imports.push(parseImport(ctx));
      ctx.skipNewlines();
      continue;
    }

    if (kind === "module" && ctx.isAt("INCLUDE")) {
      if (!moduleName) {
        throw new ParseError("include requires a preceding module declaration", ctx.loc(), {
          code: "parse.include-without-module",
          hint: "Declare `module <name>` before including PLX fragments.",
        });
      }
      includes.push(parseInclude(ctx));
      ctx.skipNewlines();
      continue;
    }

    if (kind === "module" && isExportDeclaration(ctx)) {
      if (!moduleName) {
        throw new ParseError("export requires a preceding module declaration", ctx.loc(), {
          code: "parse.export-without-module",
          hint: "Declare `module <name>` before exporting symbols from the module root.",
        });
      }
      exports.push(parseExportDecl(ctx));
      ctx.skipNewlines();
      continue;
    }

    if (kind === "fragment" && isFragmentForbiddenDirective(ctx)) {
      throw fragmentDirectiveError(ctx);
    }

    if (isSubscriptionDecl(ctx)) {
      if (!moduleName) {
        throw new ParseError("event subscriptions require a preceding module declaration", ctx.loc(), {
          code: "parse.subscription-without-module",
          hint: "Declare `module <name>` before subscribing to cross-module events.",
        });
      }
      subscriptions.push(parseSubscription(ctx));
      ctx.skipNewlines();
      continue;
    }

    const visibility = parseTopLevelVisibility(ctx, kind === "fragment" || moduleName ? "internal" : "export", kind);

    if (ctx.isAt("TRAIT")) {
      if (visibility.explicit) {
        throw new ParseError(`${visibility.value} is only supported on fn and entity declarations`, ctx.loc(), {
          code: "parse.invalid-visibility-target",
          hint: "Use export/internal before fn or entity declarations only.",
        });
      }
      traits.push(parseTrait(ctx));
    } else if (ctx.isAt("ENTITY")) {
      entities.push(parseEntity(ctx, visibility.value));
    } else if (ctx.isAt("TEST")) {
      if (visibility.explicit) {
        throw new ParseError(`${visibility.value} is only supported on fn and entity declarations`, ctx.loc(), {
          code: "parse.invalid-visibility-target",
          hint: "Use export/internal before fn or entity declarations only.",
        });
      }
      tests.push(parseTest(ctx));
    } else {
      functions.push(parseFunction(ctx, visibility.value));
    }
    ctx.skipNewlines();
  }
  return {
    name: moduleName,
    moduleLoc,
    depends,
    exports,
    includes,
    imports,
    i18n: [],
    traits,
    entities,
    functions,
    subscriptions,
    tests,
  };
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

function parseModuleDecl(ctx: ParseContext): { loc: PlxModule["moduleLoc"]; name: string } {
  const start = ctx.loc();
  ctx.expect("MODULE");
  const nameTok = ctx.expect("IDENT");
  return { name: nameTok.value, loc: mergeLoc(start, nameTok) };
}

function parseDepends(ctx: ParseContext): ModuleDependency[] {
  ctx.expect("DEPENDS");
  const depends: ModuleDependency[] = [];
  const first = ctx.expect("IDENT");
  depends.push({ name: first.value, loc: pointLoc(first.line, first.col, first.file) });
  while (ctx.isAt("COMMA")) {
    ctx.advance();
    const depTok = ctx.expect("IDENT");
    depends.push({ name: depTok.value, loc: pointLoc(depTok.line, depTok.col, depTok.file) });
  }
  return depends;
}

function parseInclude(ctx: ParseContext): ModuleInclude {
  const start = ctx.loc();
  ctx.expect("INCLUDE");
  const pathTok = ctx.expect("STRING");
  return { path: pathTok.value, loc: mergeLoc(start, pathTok) };
}

function parseExportDecl(ctx: ParseContext): ModuleExport {
  const start = ctx.loc();
  ctx.expect("EXPORT");
  const name = ctx.parseQualifiedName();
  if (!name.includes(".")) {
    throw new ParseError("export expects a qualified symbol name", start, {
      code: "parse.invalid-export-name",
      hint: "Use `export schema.symbol` from the module root.",
    });
  }
  return { name, loc: mergeLoc(start, ctx.loc()) };
}

function isExportDeclaration(ctx: ParseContext): boolean {
  if (!ctx.isAt("EXPORT")) return false;
  const next = ctx.peekAt(1);
  return next?.type !== "FN" && next?.type !== "ENTITY";
}

function isFragmentForbiddenDirective(ctx: ParseContext): boolean {
  return ctx.isAt("MODULE") || ctx.isAt("DEPENDS") || ctx.isAt("INCLUDE") || isExportDeclaration(ctx);
}

function isSubscriptionDecl(ctx: ParseContext): boolean {
  return ctx.isAt("IDENT") && ctx.peek().value === "on" && ctx.peekAt(1)?.type === "IDENT";
}

function fragmentDirectiveError(ctx: ParseContext): ParseError {
  const tok = ctx.peek();
  const keyword = tok.value || tok.type.toLowerCase();
  return new ParseError(`'${keyword}' is only allowed in the module entry file`, ctx.loc(), {
    code: "parse.fragment-root-only-directive",
    hint: "Keep `module`, `depends`, `include` and root export declarations in the entry .plx file only.",
  });
}

function parseTopLevelVisibility(
  ctx: ParseContext,
  defaultVisibility: Visibility,
  kind: ParseOptions["kind"],
): { explicit: boolean; value: Visibility } {
  if (ctx.isAt("EXPORT")) {
    if (kind === "fragment") {
      throw new ParseError("export visibility is not allowed inside included fragments", ctx.loc(), {
        code: "parse.fragment-visibility",
        hint: "Declare exported symbols from the module entry file with `export schema.symbol`.",
      });
    }
    ctx.advance();
    return { explicit: true, value: "export" };
  }
  if (ctx.isAt("INTERNAL")) {
    if (kind === "fragment") {
      throw new ParseError("internal visibility is not allowed inside included fragments", ctx.loc(), {
        code: "parse.fragment-visibility",
        hint: "Fragments are internal by default. Remove the `internal` keyword here.",
      });
    }
    ctx.advance();
    return { explicit: true, value: "internal" };
  }
  return { explicit: false, value: defaultVisibility };
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

function parseFunction(ctx: ParseContext, visibility: Visibility): PlxFunction {
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
    visibility,
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

function parseSubscription(ctx: ParseContext): PlxSubscription {
  const start = ctx.loc();
  ctx.expect("IDENT"); // on
  const sourceSchema = ctx.expect("IDENT").value;
  ctx.expect("DOT");
  const sourceEntity = ctx.expect("IDENT").value;
  ctx.expect("DOT");
  const event = ctx.expect("IDENT").value;
  ctx.expect("LPAREN");
  const params = parseNameList(ctx);
  ctx.expect("RPAREN");
  ctx.expect("COLON");
  ctx.skipNewlines();
  ctx.expect("INDENT");
  const body = ctx.parseBlock();
  const end = ctx.expect("DEDENT");
  return {
    kind: "subscription",
    sourceSchema,
    sourceEntity,
    event,
    params,
    body,
    loc: mergeLoc(start, end),
  };
}

function parseNameList(ctx: ParseContext): string[] {
  return parseCommaSeparated(ctx, "RPAREN", () => ctx.expect("IDENT").value);
}

function parseParams(ctx: ParseContext): Param[] {
  return parseCommaSeparated(ctx, "RPAREN", () => parseParam(ctx));
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
    } else if (tok.type === "BOOLEAN") {
      ctx.advance();
      defaultValue = tok.value;
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
