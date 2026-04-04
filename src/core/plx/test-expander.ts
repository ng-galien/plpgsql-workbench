// PLX Test Expander — Transforms PlxTest[] into PlxFunction[] (pgTAP-compatible)

import type { Expression, Loc, PlxFunction, PlxTest, Statement } from "./ast.js";

interface TestExpandResult {
  functions: PlxFunction[];
  errors: TestExpandError[];
}

interface TestExpandError {
  loc: Loc;
  message: string;
}

/**
 * Expand test blocks into pgTAP-compatible PlxFunction[].
 * Each test becomes a function in {schema}_ut with RETURNS SETOF text.
 * Assert statements stay in the body — codegen handles emission.
 */
export function expandTests(tests: PlxTest[]): TestExpandResult {
  const functions: PlxFunction[] = [];
  const errors: TestExpandError[] = [];

  for (const test of tests) {
    const schema = inferSchema(test.body);
    if (!schema) {
      errors.push({
        loc: test.loc,
        message: `test "${test.name}": cannot infer schema — no qualified function call found in body`,
      });
      continue;
    }

    const slug = slugify(test.name);
    functions.push({
      kind: "function",
      visibility: "internal",
      schema: `${schema}_ut`,
      name: `test_${slug}`,
      params: [],
      returnType: "text",
      setof: true,
      attributes: [],
      body: test.body,
      loc: test.loc,
    });
  }

  return { functions, errors };
}

/**
 * Infer the target schema from the first qualified function call in the test body.
 * Scans statements recursively for a call like `expense.category_create(...)`.
 */
function inferSchema(stmts: Statement[]): string | undefined {
  for (const stmt of stmts) {
    const found = findQualifiedCall(stmt);
    if (found) return found;
  }
  return undefined;
}

function findQualifiedCall(stmt: Statement): string | undefined {
  switch (stmt.kind) {
    case "assign":
      return findQualifiedCallInExpr(stmt.value);
    case "assert":
      return findQualifiedCallInExpr(stmt.expression);
    case "if":
      return (
        findQualifiedCallInExpr(stmt.condition) ??
        inferSchema(stmt.body) ??
        inferSchema(stmt.elsifs?.flatMap((e) => e.body) ?? []) ??
        (stmt.elseBody ? inferSchema(stmt.elseBody) : undefined)
      );
    case "for_in":
      return inferSchema(stmt.body);
    case "try_catch":
      return inferSchema(stmt.body) ?? inferSchema(stmt.catchBody);
    case "return":
      return findQualifiedCallInExpr(stmt.value);
    default:
      return undefined;
  }
}

function findQualifiedCallInExpr(expr: Expression): string | undefined {
  if (expr.kind === "call") {
    if (expr.name.includes(".")) return expr.name.split(".")[0];
    // Search inside arguments (e.g. count(expense.list_items()))
    for (const arg of expr.args) {
      const found = findQualifiedCallInExpr(arg);
      if (found) return found;
    }
  }
  if (expr.kind === "binary") {
    return findQualifiedCallInExpr(expr.left) ?? findQualifiedCallInExpr(expr.right);
  }
  if (expr.kind === "unary") {
    return findQualifiedCallInExpr(expr.expression);
  }
  if (expr.kind === "group") {
    return findQualifiedCallInExpr(expr.expression);
  }
  return undefined;
}

/** "category crud lifecycle" -> "category_crud_lifecycle" */
function slugify(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_|_$/g, "");
}
