import type {
  AppendStatement,
  ArrayLiteral,
  AssignStatement,
  BinaryExpr,
  CallExpr,
  CaseExpr,
  Expression,
  FieldAccess,
  ForInStatement,
  Identifier,
  IfStatement,
  JsonLiteral,
  Literal,
  MatchStatement,
  Param,
  PlxFunction,
  RaiseStatement,
  ReturnStatement,
  SqlBlockExpr,
  SqlStatement,
  Statement,
  StringInterp,
} from "./ast.js";
import { sqlEscape } from "./util.js";

// Hoisted regexes
const SELECT_FROM_RE = /^(select\s+.+?\s+)(from\s+)/is;
const SELECT_NO_FROM_RE = /^select\s+/i;
const WITH_RE = /^with\s+/i;
const WITH_FROM_RE = /^(.*\bselect\s+.+?\s+)(from\s+)/is;
const RETURNING_RE = /\breturning\b/i;
const RETURNING_APPEND_RE = /\b(returning\s+.+)$/i;
const INFER_COUNT_RE = /^select\s+count\s*\(/i;
const INFER_INT_RE = /^select\s+\d+/i;
const INFER_BOOL_RE = /^select\s+(?:true|false)/i;
const INFER_TEXT_RE = /^select\s+'/i;
const INFER_RETURNING_ROW_RE = /(?:insert\s+into|update|delete\s+from)\s+(\w+\.\w+).*\breturning\s+\*/i;
const INFER_RETURNING_SCALAR_RE = /\breturning\s+\w+\s*$/i;

const INDENTS = ["", "  ", "    ", "      ", "        ", "          "];

interface VarInfo {
  plName: string;
  type: string;
  init?: string;
  isRow: boolean;
}

export function generate(fn: PlxFunction): string {
  return new CodegenContext(fn).emit();
}

class CodegenContext {
  private vars = new Map<string, VarInfo>();
  private paramNames: Set<string>;
  private lines: string[] = [];
  private indent = 1;

  constructor(private fn: PlxFunction) {
    this.paramNames = new Set(fn.params.map((p) => p.name));
    this.collectVars(fn.body);
  }

  emit(): string {
    const parts: string[] = [];

    const params = this.fn.params.map(formatParam).join(", ");
    const returns = this.fn.setof ? `SETOF ${this.fn.returnType}` : this.fn.returnType;

    parts.push(`CREATE OR REPLACE FUNCTION ${this.fn.schema}.${this.fn.name}(${params})`);

    // Function attributes
    const attrParts: string[] = [];
    const attrs = this.fn.attributes;
    if (attrs.includes("stable")) attrParts.push("STABLE");
    else if (attrs.includes("immutable")) attrParts.push("IMMUTABLE");
    if (attrs.includes("definer")) attrParts.push("SECURITY DEFINER");
    if (attrs.includes("strict")) attrParts.push("STRICT");

    const langAndAttrs = [`RETURNS ${returns}`, "LANGUAGE plpgsql", ...attrParts].join("\n ");
    parts.push(` ${langAndAttrs} AS $$`);

    if (this.vars.size > 0) {
      parts.push("DECLARE");
      for (const v of this.vars.values()) {
        const init = v.init ? ` := ${v.init}` : "";
        parts.push(`  ${v.plName} ${v.type}${init};`);
      }
    }

    parts.push("BEGIN");
    for (const stmt of this.fn.body) this.emitStatement(stmt);
    for (const line of this.lines) parts.push(line);
    parts.push("END;");
    parts.push("$$;");

    return parts.join("\n");
  }

  // ---------- DECLARE inference ----------

  private collectVars(stmts: Statement[]): void {
    for (const stmt of stmts) {
      if (stmt.kind === "assign" && stmt.target !== "_") {
        if (!this.paramNames.has(stmt.target) && !this.vars.has(stmt.target)) {
          this.vars.set(stmt.target, this.inferVar(stmt.target, stmt.value));
        }
      }
      if (stmt.kind === "append" && !this.vars.has(stmt.target)) {
        this.vars.set(stmt.target, { plName: `v_${stmt.target}`, type: "jsonb", init: "'[]'::jsonb", isRow: false });
      }
      if (stmt.kind === "if") {
        this.collectVars(stmt.body);
        for (const ei of stmt.elsifs) this.collectVars(ei.body);
        if (stmt.elseBody) this.collectVars(stmt.elseBody);
      }
      if (stmt.kind === "for_in") {
        if (!this.vars.has(stmt.variable)) {
          this.vars.set(stmt.variable, { plName: `v_${stmt.variable}`, type: "record", isRow: false });
        }
        this.collectVars(stmt.body);
      }
      if (stmt.kind === "match") {
        for (const arm of stmt.arms) this.collectVars(arm.body);
        if (stmt.elseBody) this.collectVars(stmt.elseBody);
      }
    }
  }

  private inferVar(name: string, value: Expression): VarInfo {
    const plName = `v_${name}`;

    if (value.kind === "sql_block") {
      const sql = value.sql.toLowerCase().trim();
      if (value.inferredTable) return { plName, type: value.inferredTable, isRow: true };
      if (INFER_COUNT_RE.test(sql)) return { plName, type: "bigint", isRow: false };
      if (INFER_INT_RE.test(sql)) return { plName, type: "integer", isRow: false };
      if (INFER_BOOL_RE.test(sql)) return { plName, type: "boolean", isRow: false };
      if (INFER_TEXT_RE.test(sql)) return { plName, type: "text", isRow: false };
      const returningRow = sql.match(INFER_RETURNING_ROW_RE);
      if (returningRow) return { plName, type: returningRow[1]!, isRow: true };
      if (INFER_RETURNING_SCALAR_RE.test(sql)) return { plName, type: "record", isRow: false };
      return { plName, type: "record", isRow: false };
    }
    if (value.kind === "array_literal") return { plName, type: "jsonb", init: "'[]'::jsonb", isRow: false };
    if (value.kind === "json_literal") return { plName, type: "jsonb", isRow: false };
    if (value.kind === "string_interp") return { plName, type: "text", isRow: false };
    if (value.kind === "call") {
      const fn = value.name.toLowerCase();
      if (fn === "count" || fn === "sum") return { plName, type: "bigint", isRow: false };
      if (fn === "now" || fn === "clock_timestamp") return { plName, type: "timestamptz", isRow: false };
      if (fn === "format" || fn === "concat" || fn === "upper" || fn === "lower" || fn === "trim") {
        return { plName, type: "text", isRow: false };
      }
      if (fn === "jsonb_build_object" || fn === "to_jsonb" || fn === "row_to_json") {
        return { plName, type: "jsonb", isRow: false };
      }
      return { plName, type: "record", isRow: false };
    }
    if (value.kind === "literal") {
      if (value.type === "int") return { plName, type: "integer", init: String(value.value), isRow: false };
      if (value.type === "text")
        return { plName, type: "text", init: `'${sqlEscape(String(value.value))}'`, isRow: false };
      if (value.type === "boolean") return { plName, type: "boolean", init: String(value.value), isRow: false };
    }
    return { plName, type: "jsonb", isRow: false };
  }

  // ---------- Statement emission ----------

  private emitStatement(stmt: Statement): void {
    switch (stmt.kind) {
      case "assign":
        this.emitAssign(stmt);
        break;
      case "append":
        this.emitAppend(stmt);
        break;
      case "if":
        this.emitIf(stmt);
        break;
      case "for_in":
        this.emitFor(stmt);
        break;
      case "return":
        this.emitReturn(stmt);
        break;
      case "raise":
        this.emitRaise(stmt);
        break;
      case "match":
        this.emitMatch(stmt);
        break;
      case "sql_statement":
        this.emitSqlStatement(stmt);
        break;
    }
  }

  private emitAssign(stmt: AssignStatement): void {
    if (stmt.target === "_") {
      this.line(`PERFORM ${this.emitExpr(stmt.value)};`);
      return;
    }
    const varInfo = this.vars.get(stmt.target);
    const plName = varInfo?.plName ?? stmt.target;

    if (stmt.value.kind === "sql_block") {
      this.emitSqlAssign(plName, stmt.value);
      return;
    }
    if (varInfo?.init && this.isInitEquivalent(varInfo.init, stmt.value)) return;
    this.line(`${plName} := ${this.emitExpr(stmt.value)};`);
  }

  private isInitEquivalent(init: string, value: Expression): boolean {
    if (value.kind === "array_literal" && value.elements.length === 0 && init === "'[]'::jsonb") return true;
    if (value.kind === "literal" && init === String(value.value)) return true;
    return false;
  }

  private emitSqlAssign(plName: string, sql: SqlBlockExpr): void {
    let sqlText = sql.sql;
    const lowerSql = sqlText.toLowerCase().trim();

    // Parenthesized subquery: := (SELECT ...) → direct assignment, no INTO
    if (lowerSql.startsWith("(")) {
      this.line(`${plName} := ${sqlText};`);
      this.emitNotFoundGuard(sql.elseRaise);
      return;
    }

    // SELECT ... FROM ... → SELECT ... INTO v_x FROM ...
    const fromMatch = sqlText.match(SELECT_FROM_RE);
    if (fromMatch) {
      sqlText = `${fromMatch[1]}INTO ${plName} ${fromMatch[2]}${sqlText.slice(fromMatch[0].length)}`;
    }
    // SELECT expr (no FROM)
    else if (SELECT_NO_FROM_RE.test(lowerSql) && !lowerSql.includes(" from ")) {
      sqlText = sqlText.replace(SELECT_NO_FROM_RE, `$&INTO ${plName} `);
    }
    // WITH ... SELECT ... FROM
    else if (WITH_RE.test(lowerSql)) {
      const lastFromMatch = sqlText.match(WITH_FROM_RE);
      if (lastFromMatch) {
        sqlText = `${lastFromMatch[1]}INTO ${plName} ${lastFromMatch[2]}${sqlText.slice(lastFromMatch[0].length)}`;
      }
    }
    // INSERT/UPDATE/DELETE ... RETURNING → append INTO after RETURNING clause
    else if (RETURNING_RE.test(lowerSql)) {
      sqlText = sqlText.replace(RETURNING_APPEND_RE, `$1 INTO ${plName}`);
    }

    this.line(`${sqlText};`);
    this.emitNotFoundGuard(sql.elseRaise);
  }

  private emitNotFoundGuard(msg: string | undefined): void {
    if (!msg) return;
    this.line("IF NOT FOUND THEN");
    this.indent++;
    this.line(`RAISE EXCEPTION '${sqlEscape(msg)}';`);
    this.indent--;
    this.line("END IF;");
  }

  private emitAppend(stmt: AppendStatement): void {
    const varInfo = this.vars.get(stmt.target);
    const plName = varInfo?.plName ?? `v_${stmt.target}`;
    this.line(`${plName} := ${plName} || ${this.emitExpr(stmt.value)};`);
  }

  private emitIf(stmt: IfStatement): void {
    this.line(`IF ${this.emitExpr(stmt.condition)} THEN`);
    this.indent++;
    for (const s of stmt.body) this.emitStatement(s);
    this.indent--;
    for (const elsif of stmt.elsifs) {
      this.line(`ELSIF ${this.emitExpr(elsif.condition)} THEN`);
      this.indent++;
      for (const s of elsif.body) this.emitStatement(s);
      this.indent--;
    }
    if (stmt.elseBody) {
      this.line("ELSE");
      this.indent++;
      for (const s of stmt.elseBody) this.emitStatement(s);
      this.indent--;
    }
    this.line("END IF;");
  }

  private emitFor(stmt: ForInStatement): void {
    this.line(`FOR v_${stmt.variable} IN ${stmt.query} LOOP`);
    this.indent++;
    for (const s of stmt.body) this.emitStatement(s);
    this.indent--;
    this.line("END LOOP;");
  }

  private emitReturn(stmt: ReturnStatement): void {
    // Bare return
    if (stmt.value.kind === "literal" && stmt.value.type === "null") {
      this.line("RETURN;");
      return;
    }

    // return query → RETURN QUERY
    if (stmt.mode === "query") {
      this.line(`RETURN QUERY ${this.emitExpr(stmt.value)};`);
      return;
    }

    // return execute → RETURN QUERY EXECUTE
    if (stmt.mode === "execute") {
      this.line(`RETURN QUERY EXECUTE ${this.emitExpr(stmt.value)};`);
      return;
    }

    // yield / setof → RETURN NEXT
    if (stmt.isYield || this.fn.setof) {
      if (stmt.value.kind === "sql_block") {
        this.line(`RETURN QUERY ${stmt.value.sql};`);
      } else {
        this.line(`RETURN NEXT ${this.emitExpr(stmt.value)};`);
      }
      return;
    }

    this.line(`RETURN ${this.emitExpr(stmt.value)};`);
  }

  private emitRaise(stmt: RaiseStatement): void {
    this.line(`RAISE EXCEPTION '${sqlEscape(stmt.message)}';`);
  }

  private emitMatch(stmt: MatchStatement): void {
    this.line(`CASE ${this.emitExpr(stmt.subject)}`);
    this.indent++;
    for (const arm of stmt.arms) {
      this.line(`WHEN ${this.emitExpr(arm.pattern)} THEN`);
      this.indent++;
      for (const s of arm.body) this.emitStatement(s);
      this.indent--;
    }
    if (stmt.elseBody) {
      this.line("ELSE");
      this.indent++;
      for (const s of stmt.elseBody) this.emitStatement(s);
      this.indent--;
    }
    this.indent--;
    this.line("END CASE;");
  }

  private emitSqlStatement(stmt: SqlStatement): void {
    this.line(`${stmt.sql};`);
  }

  // ---------- Expression emission ----------

  private emitExpr(expr: Expression): string {
    switch (expr.kind) {
      case "sql_block":
        return expr.sql;
      case "json_literal":
        return this.emitJson(expr);
      case "array_literal":
        return this.emitArray(expr);
      case "string_interp":
        return this.emitInterp(expr);
      case "field_access":
        return this.emitFieldAccess(expr);
      case "identifier":
        return this.emitIdent(expr);
      case "literal":
        return emitLiteral(expr);
      case "binary":
        return this.emitBinary(expr);
      case "call":
        return this.emitCall(expr);
      case "case_expr":
        return this.emitCaseExpr(expr);
    }
  }

  private emitJson(json: JsonLiteral): string {
    if (json.entries.length === 0) return "'{}'::jsonb";
    const pairs = json.entries.map((e) => `'${e.key}', ${this.emitJsonValue(e.value)}`);
    return `jsonb_build_object(${pairs.join(", ")})`;
  }

  private emitJsonValue(expr: Expression): string {
    if (expr.kind === "identifier") {
      const varInfo = this.vars.get(expr.name);
      if (varInfo?.isRow) return `row_to_json(${varInfo.plName})::jsonb`;
      return this.emitIdent(expr);
    }
    return this.emitExpr(expr);
  }

  private emitArray(arr: ArrayLiteral): string {
    if (arr.elements.length === 0) return "'[]'::jsonb";
    return `jsonb_build_array(${arr.elements.map((e) => this.emitExpr(e)).join(", ")})`;
  }

  private emitInterp(interp: StringInterp): string {
    return interp.parts.map((p) => (typeof p === "string" ? `'${sqlEscape(p)}'` : this.emitExpr(p))).join(" || ");
  }

  private emitFieldAccess(fa: FieldAccess): string {
    return `${this.resolveVarName(fa.object)}.${fa.field}`;
  }

  private emitIdent(id: Identifier): string {
    return this.resolveVarName(id.name);
  }

  private emitBinary(bin: BinaryExpr): string {
    if (bin.op === "IS NOT NULL") return `${this.emitExpr(bin.left)} IS NOT NULL`;
    if (bin.op === "NOT") return `NOT ${this.emitExpr(bin.right)}`;
    // x = null → x IS NULL, x != null → x IS NOT NULL (SQL three-valued logic)
    if (isNullExpr(bin.right)) {
      if (bin.op === "=") return `${this.emitExpr(bin.left)} IS NULL`;
      if (bin.op === "!=") return `${this.emitExpr(bin.left)} IS NOT NULL`;
    }
    if (isNullExpr(bin.left)) {
      if (bin.op === "=") return `${this.emitExpr(bin.right)} IS NULL`;
      if (bin.op === "!=") return `${this.emitExpr(bin.right)} IS NOT NULL`;
    }
    // :: type cast — no spaces
    if (bin.op === "::") return `${this.emitExpr(bin.left)}::${this.emitExpr(bin.right)}`;
    return `${this.emitExpr(bin.left)} ${bin.op} ${this.emitExpr(bin.right)}`;
  }

  private emitCall(call: CallExpr): string {
    return `${call.name}(${call.args.map((a) => this.emitExpr(a)).join(", ")})`;
  }

  private emitCaseExpr(c: CaseExpr): string {
    const arms = c.arms.map((a) => `WHEN ${this.emitExpr(a.pattern)} THEN ${this.emitExpr(a.result)}`).join(" ");
    const elseClause = c.elseResult ? ` ELSE ${this.emitExpr(c.elseResult)}` : "";
    return `CASE ${this.emitExpr(c.subject)} ${arms}${elseClause} END`;
  }

  // ---------- Helpers ----------

  private resolveVarName(name: string): string {
    if (this.paramNames.has(name)) return name;
    const v = this.vars.get(name);
    return v ? v.plName : name;
  }

  private line(text: string): void {
    this.lines.push((INDENTS[this.indent] ?? "  ".repeat(this.indent)) + text);
  }
}

function isNullExpr(expr: Expression): boolean {
  if (expr.kind === "literal" && expr.type === "null") return true;
  if (expr.kind === "identifier" && expr.name === "null") return true;
  return false;
}

function emitLiteral(lit: Literal): string {
  if (lit.type === "text") return `'${sqlEscape(String(lit.value))}'`;
  if (lit.type === "null") return "NULL";
  return String(lit.value);
}

function formatParam(p: Param): string {
  let s = `${p.name} ${p.type}`;
  if (p.defaultValue !== undefined) s += ` DEFAULT ${p.defaultValue}`;
  return s;
}
