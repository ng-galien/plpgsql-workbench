import { generate } from "./codegen.js";
import { expandEntities } from "./entity-expander.js";
import { tokenize } from "./lexer.js";
import { parse } from "./parser.js";

export interface CompileResult {
  sql: string;
  ddlSql?: string;
  errors: CompileError[];
  warnings: CompileWarning[];
  functionCount: number;
  entityCount?: number;
}

export interface CompileError {
  line: number;
  col: number;
  message: string;
  phase: "lex" | "parse" | "codegen" | "validate";
}

export interface CompileWarning {
  message: string;
  functionName: string;
}

const LOC_RE = /plx:(\d+):(\d+)/;
const FN_NAME_RE = /FUNCTION\s+(\S+)\(/;

export function compile(source: string): CompileResult {
  const errors: CompileError[] = [];

  let tokens: ReturnType<typeof tokenize>;
  try {
    tokens = tokenize(source);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    errors.push({ ...extractLoc(msg), message: msg, phase: "lex" });
    return { sql: "", errors, warnings: [], functionCount: 0 };
  }

  let mod: ReturnType<typeof parse>;
  try {
    mod = parse(tokens);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    errors.push({ ...extractLoc(msg), message: msg, phase: "parse" });
    return { sql: "", errors, warnings: [], functionCount: 0 };
  }

  // Expand entities into functions + DDL
  const expandResult = expandEntities(mod);
  for (const err of expandResult.errors) {
    errors.push({ line: err.loc.line, col: err.loc.col, message: err.message, phase: "codegen" });
  }
  if (errors.length > 0) {
    return { sql: "", errors, warnings: [], functionCount: 0 };
  }

  // Merge expanded functions with hand-written ones
  const allFunctions = [...mod.functions, ...expandResult.functions];

  // Build alias map from imports
  const aliases = new Map<string, string>();
  for (const imp of mod.imports) {
    aliases.set(imp.alias, imp.original);
  }

  const sqlParts: string[] = [];
  for (const fn of allFunctions) {
    try {
      sqlParts.push(generate(fn, aliases));
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      errors.push({ line: fn.loc.line, col: fn.loc.col, message: msg, phase: "codegen" });
    }
  }

  if (errors.length > 0) {
    return { sql: "", errors, warnings: [], functionCount: 0 };
  }

  const ddlSql = expandResult.ddlFragments.length > 0 ? expandResult.ddlFragments.join("\n\n") : undefined;

  return {
    sql: sqlParts.join("\n\n"),
    ddlSql,
    errors: [],
    warnings: [],
    functionCount: allFunctions.length,
    entityCount: mod.entities.length,
    // Attach individual blocks for validation without re-splitting
    _blocks: sqlParts,
  } as CompileResult & { _blocks: string[] };
}

/**
 * Compile with PG parser validation — validates each generated function
 * through @libpg-query/parser to catch SQL syntax errors.
 */
/**
 * Compile with PG parser validation. Uses dynamic import to avoid loading
 * the heavy WASM module (~4GB) when validation is not requested.
 */
export async function compileAndValidate(source: string): Promise<CompileResult> {
  const result = compile(source) as CompileResult & { _blocks?: string[] };
  if (result.errors.length > 0) return result;

  // Dynamic import — only loads WASM when validation is actually called
  const { loadModule, parsePlPgSQL } = await import("@libpg-query/parser");
  await loadModule();

  const warnings: CompileWarning[] = [];
  const blocks = result._blocks ?? [result.sql];

  for (const block of blocks) {
    const nameMatch = block.match(FN_NAME_RE);
    const fnName = nameMatch?.[1] ?? "unknown";
    try {
      parsePlPgSQL(block);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      warnings.push({ message: `PG parse: ${msg}`, functionName: fnName });
    }
  }

  delete result._blocks;
  return { ...result, warnings };
}

function extractLoc(msg: string): { line: number; col: number } {
  const m = msg.match(LOC_RE);
  return m ? { line: Number(m[1]), col: Number(m[2]) } : { line: 0, col: 0 };
}
