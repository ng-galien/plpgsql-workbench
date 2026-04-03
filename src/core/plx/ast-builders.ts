import type {
  ArrayLiteral,
  AssignStatement,
  Expression,
  JsonLiteral,
  Loc,
  ReturnStatement,
  SqlBlockExpr,
  Statement,
} from "./ast.js";
import { pointLoc } from "./ast.js";

const LOC: Loc = pointLoc();

export function textLiteral(value: string, loc: Loc = LOC): Expression {
  return { kind: "literal", value, type: "text", loc };
}

export function nullLiteral(loc: Loc = LOC): Expression {
  return { kind: "literal", value: null, type: "null", loc };
}

export function identifierExpr(name: string, loc: Loc = LOC): Expression {
  return { kind: "identifier", name, loc };
}

export function fieldAccessExpr(object: string, field: string, loc: Loc = LOC): Expression {
  return { kind: "field_access", object, field, loc };
}

export function qualifiedIdentifierExpr(name: string, loc: Loc = LOC): Expression {
  const [object, field] = name.split(".");
  if (!object || !field) return identifierExpr(name, loc);
  return fieldAccessExpr(object, field, loc);
}

export function jsonObj(entries: JsonLiteral["entries"], loc: Loc = LOC): JsonLiteral {
  return { kind: "json_literal", entries, loc };
}

export function jsonEntry(key: string, value: Expression): JsonLiteral["entries"][number] {
  return { key, value };
}

export function textArray(items: string[], loc: Loc = LOC): ArrayLiteral {
  return { kind: "array_literal", elements: items.map((item) => textLiteral(item, loc)), loc };
}

export function sqlBlock(
  sql: string,
  elseRaise?: string,
  inferredTable?: string,
  inferredTypeOrLoc?: string | Loc,
  loc: Loc = LOC,
): SqlBlockExpr {
  const inferredType = typeof inferredTypeOrLoc === "string" ? inferredTypeOrLoc : undefined;
  const resolvedLoc = typeof inferredTypeOrLoc === "string" ? loc : (inferredTypeOrLoc ?? loc);
  return { kind: "sql_block", sql, elseRaise, inferredTable, inferredType, loc: resolvedLoc };
}

export function assignStmt(target: string, value: Expression, loc: Loc = LOC): AssignStatement {
  return { kind: "assign", target, value, loc };
}

export function returnStmt(mode: ReturnStatement["mode"], value: Expression, loc: Loc = LOC): ReturnStatement {
  return { kind: "return", value, isYield: false, mode, loc };
}

export function castExpr(left: Expression, right: Expression, loc: Loc = LOC): Expression {
  return { kind: "binary", op: "::", left, right, loc };
}

export function assertStmt(expression: Expression, message: string, loc: Loc = LOC): Statement {
  return { kind: "assert", expression, message, loc };
}

export function rawSqlExpr(sql: string, loc: Loc = LOC): SqlBlockExpr {
  return { kind: "sql_block", sql, loc };
}
