/**
 * AST-based dependency extraction for SQL and PL/pgSQL functions.
 * Uses @libpg-query/parser to parse function bodies and find
 * schema-qualified function calls (e.g. pgv.esc).
 */
import { loadModule, parse, parsePlPgSQL } from "@libpg-query/parser";

let moduleLoaded = false;
export async function ensureParserModule(): Promise<void> {
  if (!moduleLoaded) {
    await loadModule();
    moduleLoaded = true;
  }
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Node = any;

/** Collect all schema-qualified function calls from a SQL AST node (recursive) */
function collectFuncCalls(node: Node, out: Set<string>): void {
  if (!node || typeof node !== "object") return;

  if (node.FuncCall?.funcname) {
    const parts = node.FuncCall.funcname;
    if (Array.isArray(parts) && parts.length === 2) {
      const schema = parts[0]?.String?.sval;
      const name = parts[1]?.String?.sval;
      if (schema && name) out.add(`${schema}.${name}`);
    }
  }

  for (const val of Object.values(node)) {
    if (Array.isArray(val)) {
      for (const item of val) collectFuncCalls(item, out);
    } else if (val && typeof val === "object") {
      collectFuncCalls(val, out);
    }
  }
}

/** Extract SQL expressions from PL/pgSQL AST (recursive) */
function collectPlpgsqlExprs(node: Node, out: string[]): void {
  if (!node || typeof node !== "object") return;

  if (node.PLpgSQL_expr?.query) {
    out.push(node.PLpgSQL_expr.query);
  }

  for (const val of Object.values(node)) {
    if (Array.isArray(val)) {
      for (const item of val) collectPlpgsqlExprs(item, out);
    } else if (val && typeof val === "object") {
      collectPlpgsqlExprs(val, out);
    }
  }
}

/** Extract the function body from DDL (between $tag$...$tag$ delimiters) */
function extractBody(ddl: string): string | null {
  const match = ddl.match(/\$([^$]*)\$([\s\S]*)\$\1\$/);
  return match ? match[2]! : null;
}

/** Normalize PL/pgSQL expression for SQL parsing (strip assignment) */
function normalizePlExpr(expr: string): string {
  const assignMatch = expr.match(/^\s*\w+\s*:=\s*([\s\S]+)$/);
  return assignMatch ? assignMatch[1]! : expr;
}

export interface FuncInfo {
  schema: string;
  name: string;
  lang: string;
  ddl: string;
}

/**
 * Extract all schema-qualified function calls from a function's DDL via AST.
 * Works for both SQL and PL/pgSQL functions.
 * Returns a set of "schema.name" strings.
 */
export async function extractFuncDeps(fn: FuncInfo): Promise<Set<string>> {
  const calls = new Set<string>();

  if (fn.lang === "sql") {
    const body = extractBody(fn.ddl);
    if (!body) return calls;
    try {
      const ast = await parse(body);
      collectFuncCalls(ast, calls);
    } catch {
      /* unparseable SQL — skip */
    }
  } else if (fn.lang === "plpgsql") {
    try {
      const ast = await parsePlPgSQL(fn.ddl);
      const exprs: string[] = [];
      collectPlpgsqlExprs(ast, exprs);
      for (const expr of exprs) {
        const normalized = normalizePlExpr(expr);
        try {
          const sqlAst = await parse(`SELECT ${normalized}`);
          collectFuncCalls(sqlAst, calls);
        } catch {
          /* unparseable expression — skip */
        }
      }
    } catch {
      /* unparseable PL/pgSQL — skip */
    }
  }

  // Remove self-reference
  calls.delete(`${fn.schema}.${fn.name}`);
  return calls;
}
