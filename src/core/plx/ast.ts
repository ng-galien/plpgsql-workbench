// PLX AST — Phase 1: Function blocks only

export interface Loc {
  line: number;
  col: number;
}

// ---------- Top-level ----------

export type FuncAttribute = "stable" | "immutable" | "volatile" | "definer" | "strict";

export interface PlxFunction {
  kind: "function";
  schema: string;
  name: string;
  params: Param[];
  returnType: string;
  setof: boolean;
  attributes: FuncAttribute[];
  body: Statement[];
  loc: Loc;
}

export interface Param {
  name: string;
  type: string;
  nullable: boolean;
  defaultValue?: string;
}

// ---------- Statements ----------

export type Statement =
  | AssignStatement
  | IfStatement
  | ForInStatement
  | ReturnStatement
  | RaiseStatement
  | MatchStatement
  | SqlStatement
  | AppendStatement;

export interface AssignStatement {
  kind: "assign";
  target: string;
  value: Expression;
  loc: Loc;
}

export interface IfStatement {
  kind: "if";
  condition: Expression;
  body: Statement[];
  elsifs: { condition: Expression; body: Statement[] }[];
  elseBody?: Statement[];
  loc: Loc;
}

export interface ForInStatement {
  kind: "for_in";
  variable: string;
  query: string;
  body: Statement[];
  loc: Loc;
}

export type ReturnMode = "value" | "query" | "execute";

export interface ReturnStatement {
  kind: "return";
  value: Expression;
  isYield: boolean;
  mode: ReturnMode; // value = RETURN, query = RETURN QUERY, execute = RETURN QUERY EXECUTE
  loc: Loc;
}

export interface RaiseStatement {
  kind: "raise";
  message: string;
  loc: Loc;
}

export interface MatchStatement {
  kind: "match";
  subject: Expression;
  arms: { pattern: Expression; body: Statement[] }[];
  elseBody?: Statement[];
  loc: Loc;
}

export interface SqlStatement {
  kind: "sql_statement";
  sql: string;
  loc: Loc;
}

export interface AppendStatement {
  kind: "append";
  target: string;
  value: Expression;
  loc: Loc;
}

// ---------- Expressions ----------

export type Expression =
  | SqlBlockExpr
  | JsonLiteral
  | ArrayLiteral
  | StringInterp
  | FieldAccess
  | Identifier
  | Literal
  | BinaryExpr
  | CallExpr
  | CaseExpr;

export interface CaseExpr {
  kind: "case_expr";
  subject: Expression;
  arms: { pattern: Expression; result: Expression }[];
  elseResult?: Expression;
  loc: Loc;
}

export type BinaryOp =
  | "IS NOT NULL"
  | "NOT"
  | "AND"
  | "OR"
  | "="
  | "!="
  | ">"
  | "<"
  | ">="
  | "<="
  | "+"
  | "-"
  | "*"
  | "/";

export interface SqlBlockExpr {
  kind: "sql_block";
  sql: string;
  elseRaise?: string;
  inferredTable?: string;
  loc: Loc;
}

export interface JsonLiteral {
  kind: "json_literal";
  entries: { key: string; value: Expression }[];
  loc: Loc;
}

export interface ArrayLiteral {
  kind: "array_literal";
  elements: Expression[];
  loc: Loc;
}

export interface StringInterp {
  kind: "string_interp";
  parts: (string | Expression)[];
  loc: Loc;
}

export interface FieldAccess {
  kind: "field_access";
  object: string;
  field: string;
  loc: Loc;
}

export interface Identifier {
  kind: "identifier";
  name: string;
  loc: Loc;
}

export interface Literal {
  kind: "literal";
  value: string | number | boolean | null;
  type: "text" | "int" | "boolean" | "null";
  loc: Loc;
}

export interface BinaryExpr {
  kind: "binary";
  op: BinaryOp | string; // string fallback for operators not in BinaryOp
  left: Expression;
  right: Expression;
  loc: Loc;
}

export interface CallExpr {
  kind: "call";
  name: string;
  args: Expression[];
  loc: Loc;
}
