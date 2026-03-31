// PLX AST

export interface Loc {
  line: number;
  col: number;
  endLine: number;
  endCol: number;
}

export function pointLoc(line = 0, col = 0): Loc {
  return { line, col, endLine: line, endCol: col };
}

export function spanLoc(start: Pick<Loc, "line" | "col">, end: Pick<Loc, "endLine" | "endCol">): Loc {
  return {
    line: start.line,
    col: start.col,
    endLine: end.endLine,
    endCol: end.endCol,
  };
}

export function mergeLoc(start: Loc, end: Loc): Loc {
  return spanLoc(start, end);
}

export function shiftLoc(loc: Loc, lineDelta: number, colDelta: number): Loc {
  return {
    line: loc.line + lineDelta,
    col: loc.line === 1 ? loc.col + colDelta : loc.col,
    endLine: loc.endLine + lineDelta,
    endCol: loc.endLine === 1 ? loc.endCol + colDelta : loc.endCol,
  };
}

// ---------- Top-level ----------

export interface ImportAlias {
  original: string; // jsonb_build_object, pgv.t, crm.client_read
  alias: string; // obj, t, get_client
  loc: Loc;
}

export interface ModuleDependency {
  name: string;
  loc: Loc;
}

export type Visibility = "export" | "internal";

export interface PlxModule {
  name?: string;
  moduleLoc?: Loc;
  depends: ModuleDependency[];
  imports: ImportAlias[];
  traits: PlxTrait[];
  entities: PlxEntity[];
  functions: PlxFunction[];
  tests: PlxTest[];
}

// ---------- Traits ----------

export interface PlxTrait {
  kind: "trait";
  name: string;
  fields: FieldDef[];
  hooks: TraitHook[];
  defaultScope?: string; // SQL WHERE fragment injected into list/read
  loc: Loc;
}

export interface FieldDef {
  name: string;
  type: string;
  nullable: boolean;
  defaultValue?: string; // SQL expression: "now()", "'draft'"
  loc: Loc;
}

export type TraitHookEvent = "before_create" | "after_create" | "before_update" | "after_update" | "delete";

export interface TraitHook {
  event: TraitHookEvent;
  body: Statement[];
  loc: Loc;
}

// ---------- Entities ----------

export interface PlxEntity {
  kind: "entity";
  visibility: Visibility;
  schema: string;
  name: string; // "category", "expense_report"
  table: string; // "expense.category"
  uri: string; // "expense://category"
  icon?: string;
  label: string; // i18n key
  traits: string[];
  fields: EntityField[];
  states?: StateBlock;
  updateStates?: string[]; // restrict update to these states
  view: ViewBlock;
  actions: ActionDef[];
  strategies: StrategyDecl[];
  hooks: EntityHook[];
  listOrder: string; // ORDER BY fragment, default "id"
  readKey?: string; // WHERE fragment, default "t.id = p_id::int"
  loc: Loc;
}

export interface EntityField extends FieldDef {
  required: boolean;
  unique: boolean;
  createOnly: boolean;
  readOnly: boolean;
  viewType?: string; // "date", "currency", "status", "textarea"
  label?: string; // i18n key override
}

export interface StateBlock {
  column: string; // default "status"
  initial: string; // "draft"
  values: string[]; // all states
  transitions: StateTransition[];
  loc: Loc;
}

export interface StateTransition {
  name: string; // "submit"
  from: string; // "draft"
  to: string; // "submitted"
  guard?: string; // SQL boolean expression
  body?: Statement[];
  loc: Loc;
}

export interface ViewBlock {
  compact: string[];
  standard?: ViewSection;
  expanded?: ViewSection;
  form?: FormSection[];
}

export interface ViewSection {
  fields: string[];
  stats?: StatDef[];
  related?: RelatedDef[];
}

export interface StatDef {
  key: string;
  label: string;
}

export interface RelatedDef {
  entity: string; // URI
  label: string;
  filter: string; // RSQL template
}

export interface FormSection {
  label: string; // i18n key
  fields: FormField[];
}

export interface FormField {
  key: string;
  type: string; // "text", "date", "textarea", "select"
  label: string; // i18n key
  required?: boolean;
}

export interface ActionDef {
  name: string; // "edit", "delete", "submit"
  label: string; // i18n key
  icon?: string;
  variant?: string; // "muted", "primary", "danger"
  confirm?: string; // i18n key for confirmation dialog
}

export interface StrategyDecl {
  slot: string; // "read.query", "list.query", "create.enrich", "delete.guard"
  fn: string; // fully qualified function name
  loc: Loc;
}

export type EntityHookEvent = "before_create" | "after_create" | "before_update" | "after_update";

export interface EntityHook {
  event: EntityHookEvent;
  params: string[];
  body: Statement[];
  loc: Loc;
}

export type FuncAttribute = "stable" | "immutable" | "volatile" | "definer" | "strict";

export interface PlxFunction {
  kind: "function";
  visibility: Visibility;
  schema: string;
  name: string;
  params: Param[];
  returnType: string;
  setof: boolean;
  attributes: FuncAttribute[];
  body: Statement[];
  loc: Loc;
}

export interface PlxTest {
  kind: "test";
  name: string; // "category crud lifecycle"
  body: Statement[];
  loc: Loc;
}

export interface Param {
  name: string;
  type: string;
  nullable: boolean;
  defaultValue?: string;
  loc: Loc;
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
  | AppendStatement
  | AssertStatement;

export interface AssertStatement {
  kind: "assert";
  expression: Expression;
  message?: string;
  loc: Loc;
}

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
  | GroupExpr
  | UnaryExpr
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
  | "AND"
  | "OR"
  | "="
  | "!="
  | ">"
  | "<"
  | ">="
  | "<="
  | "||"
  | "+"
  | "-"
  | "*"
  | "/"
  | "::"
  | "->"
  | "->>";

export type UnaryOp = "NOT" | "+" | "-";

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

export interface GroupExpr {
  kind: "group";
  expression: Expression;
  loc: Loc;
}

export interface UnaryExpr {
  kind: "unary";
  op: UnaryOp;
  expression: Expression;
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
