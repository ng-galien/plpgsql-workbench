// PLX AST Walker — shared recursive traversal for statements and expressions.
//
// NOTE: parse-context.ts has its own `remapExpressionLocs` which mutates
// expression nodes in place (shifting source locations for interpolated
// expressions). That is a mutation pass, not a visitor, and is intentionally
// left separate.

import type { Expression, Statement } from "./ast.js";

export interface AstVisitor {
  onStatement?: (stmt: Statement) => void;
  onExpression?: (expr: Expression) => void;
}

export function walkStatements(stmts: Statement[], visitor: AstVisitor): void {
  for (const stmt of stmts) walkStatement(stmt, visitor);
}

export function walkStatement(stmt: Statement, visitor: AstVisitor): void {
  if (visitor.onStatement) visitor.onStatement(stmt);

  switch (stmt.kind) {
    case "assign":
    case "append":
      walkExpression(stmt.value, visitor);
      return;
    case "assert":
      walkExpression(stmt.expression, visitor);
      return;
    case "emit":
      for (const arg of stmt.args) walkExpression(arg, visitor);
      return;
    case "if":
      walkExpression(stmt.condition, visitor);
      walkStatements(stmt.body, visitor);
      for (const elsif of stmt.elsifs) {
        walkExpression(elsif.condition, visitor);
        walkStatements(elsif.body, visitor);
      }
      if (stmt.elseBody) walkStatements(stmt.elseBody, visitor);
      return;
    case "for_in":
      walkStatements(stmt.body, visitor);
      return;
    case "try_catch":
      walkStatements(stmt.body, visitor);
      walkStatements(stmt.catchBody, visitor);
      return;
    case "match":
      walkExpression(stmt.subject, visitor);
      for (const arm of stmt.arms) {
        walkExpression(arm.pattern, visitor);
        walkStatements(arm.body, visitor);
      }
      if (stmt.elseBody) walkStatements(stmt.elseBody, visitor);
      return;
    case "return":
      walkExpression(stmt.value, visitor);
      return;
    case "raise":
    case "sql_statement":
      return;
  }
}

export function walkExpression(expr: Expression, visitor: AstVisitor): void {
  if (visitor.onExpression) visitor.onExpression(expr);

  switch (expr.kind) {
    case "call":
      for (const arg of expr.args) walkExpression(arg, visitor);
      return;
    case "array_literal":
      for (const element of expr.elements) walkExpression(element, visitor);
      return;
    case "binary":
      walkExpression(expr.left, visitor);
      walkExpression(expr.right, visitor);
      return;
    case "case_expr":
      walkExpression(expr.subject, visitor);
      for (const arm of expr.arms) {
        walkExpression(arm.pattern, visitor);
        walkExpression(arm.result, visitor);
      }
      if (expr.elseResult) walkExpression(expr.elseResult, visitor);
      return;
    case "group":
      walkExpression(expr.expression, visitor);
      return;
    case "unary":
      walkExpression(expr.expression, visitor);
      return;
    case "json_literal":
      for (const entry of expr.entries) walkExpression(entry.value, visitor);
      return;
    case "string_interp":
      for (const part of expr.parts) {
        if (typeof part !== "string") walkExpression(part, visitor);
      }
      return;
    case "field_access":
    case "identifier":
    case "literal":
    case "sql_block":
      return;
  }
}
