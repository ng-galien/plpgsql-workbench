import type {
  AppendStatement,
  ArrayLiteral,
  AssertStatement,
  AssignStatement,
  BinaryExpr,
  CallExpr,
  CaseExpr,
  Expression,
  FieldAccess,
  ForInStatement,
  GroupExpr,
  Identifier,
  IfStatement,
  JsonLiteral,
  Literal,
  Loc,
  MatchStatement,
  Param,
  PlxFunction,
  RaiseStatement,
  ReturnStatement,
  SqlBlockExpr,
  SqlStatement,
  Statement,
  StringInterp,
  TryCatchStatement,
  UnaryExpr,
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
const INFER_JSONB_RE = /^select\s+(?:to_jsonb|jsonb_build_object|jsonb_build_array|jsonb_agg|jsonb_strip_nulls)\s*\(/i;
const INFER_INT_RE = /^select\s+\d+/i;
const INFER_BOOL_RE = /^select\s+(?:true|false)/i;
const INFER_TEXT_RE = /^select\s+'/i;
const INFER_RETURNING_ROW_RE = /(?:insert\s+into|update|delete\s+from)\s+(\w+\.\w+).*\breturning\s+\*/i;
const INFER_RETURNING_SCALAR_RE = /\breturning\s+\w+\s*$/i;

const INDENTS = ["", "  ", "    ", "      ", "        ", "          "];
const PRIMARY_PRECEDENCE = 100;

type Assoc = "left" | "right";

interface VarInfo {
  plName: string;
  type: string;
  init?: string;
  isRow: boolean;
}

export interface SourceSegment {
  startCol: number;
  endCol: number;
  loc: Loc;
  text: string;
}

export interface GeneratedLineMap {
  generatedLine: number;
  text: string;
  loc?: Loc;
  segments: SourceSegment[];
}

export interface GeneratedSourceMap {
  lines: GeneratedLineMap[];
}

interface MappedText {
  text: string;
  segments: SourceSegment[];
}

interface EmittedLine {
  text: string;
  loc?: Loc;
  segments: SourceSegment[];
}

function generate(fn: PlxFunction, aliases?: Map<string, string>): string {
  return generateWithSourceMap(fn, aliases).sql;
}

export function generateWithSourceMap(
  fn: PlxFunction,
  aliases?: Map<string, string>,
  returnTypes?: Map<string, string>,
): { sql: string; sourceMap: GeneratedSourceMap } {
  return new CodegenContext(fn, aliases, returnTypes).emit();
}

class CodegenContext {
  private vars = new Map<string, VarInfo>();
  private paramNames: Set<string>;
  private aliases: Map<string, string>;
  private returnTypes: Map<string, string>;
  private lines: EmittedLine[] = [];
  private indent = 1;

  constructor(
    private fn: PlxFunction,
    aliases?: Map<string, string>,
    returnTypes?: Map<string, string>,
  ) {
    this.paramNames = new Set(fn.params.map((p) => p.name));
    this.aliases = aliases ?? new Map();
    this.returnTypes = returnTypes ?? new Map();
    this.collectVars(fn.body);
  }

  emit(): { sql: string; sourceMap: GeneratedSourceMap } {
    const parts: EmittedLine[] = [];

    const params = this.fn.params.map(formatParam).join(", ");
    const returns = this.fn.setof ? `SETOF ${this.fn.returnType}` : this.fn.returnType;

    parts.push({
      text: `CREATE OR REPLACE FUNCTION ${this.fn.schema}.${this.fn.name}(${params})`,
      loc: this.fn.loc,
      segments: [],
    });

    // Function attributes
    const attrParts: string[] = [];
    const attrs = this.fn.attributes;
    if (attrs.includes("stable")) attrParts.push("STABLE");
    else if (attrs.includes("immutable")) attrParts.push("IMMUTABLE");
    if (attrs.includes("definer")) {
      attrParts.push("SECURITY DEFINER");
      attrParts.push(`SET search_path = ${this.fn.schema}, pg_catalog, pg_temp`);
    }
    if (attrs.includes("strict")) attrParts.push("STRICT");

    const langAndAttrs = [`RETURNS ${returns}`, "LANGUAGE plpgsql", ...attrParts].join("\n ");
    for (const line of ` ${langAndAttrs} AS $$`.split("\n")) {
      parts.push({ text: line, loc: this.fn.loc, segments: [] });
    }

    if (this.vars.size > 0) {
      parts.push({ text: "DECLARE", loc: this.fn.loc, segments: [] });
      for (const v of this.vars.values()) {
        const init = v.init ? ` := ${v.init}` : "";
        parts.push({ text: `  ${v.plName} ${v.type}${init};`, loc: this.fn.loc, segments: [] });
      }
    }

    parts.push({ text: "BEGIN", loc: this.fn.loc, segments: [] });
    for (const stmt of this.fn.body) this.emitStatement(stmt);
    for (const line of this.lines) parts.push(line);
    parts.push({ text: "END;", loc: this.fn.loc, segments: [] });
    parts.push({ text: "$$;", loc: this.fn.loc, segments: [] });

    const sourceMap: GeneratedSourceMap = {
      lines: parts.map((line, index) => ({
        generatedLine: index + 1,
        text: line.text,
        loc: line.loc,
        segments: line.segments,
      })),
    };

    return {
      sql: parts.map((line) => line.text).join("\n"),
      sourceMap,
    };
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
      if (stmt.kind === "try_catch") {
        this.collectVars(stmt.body);
        this.collectVars(stmt.catchBody);
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
      // Unwrap parenthesized subquery for inference: (SELECT ...) → SELECT ...
      let sql = value.sql.toLowerCase().trim();
      if (sql.startsWith("(") && sql.endsWith(")")) sql = sql.slice(1, -1).trim();
      if (value.inferredTable) return { plName, type: value.inferredTable, isRow: true };
      if (value.inferredType) return this.varInfoForType(plName, value.inferredType);
      if (INFER_COUNT_RE.test(sql)) return { plName, type: "bigint", isRow: false };
      if (INFER_JSONB_RE.test(sql)) return { plName, type: "jsonb", isRow: false };
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
      const targetName = this.aliases.get(value.name) ?? value.name;
      const declaredReturn = this.returnTypes.get(targetName);
      if (declaredReturn) return this.varInfoForType(plName, declaredReturn);
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

  private varInfoForType(plName: string, typeName: string): VarInfo {
    const lowered = typeName.toLowerCase();
    if (lowered === "jsonb" || lowered === "json") return { plName, type: "jsonb", isRow: false };
    if (lowered === "text") return { plName, type: "text", isRow: false };
    if (lowered === "boolean") return { plName, type: "boolean", isRow: false };
    if (lowered === "int" || lowered === "integer" || lowered === "smallint")
      return { plName, type: "integer", isRow: false };
    if (lowered === "bigint") return { plName, type: "bigint", isRow: false };
    if (lowered === "numeric" || lowered === "decimal" || lowered === "real" || lowered === "double precision") {
      return { plName, type: lowered, isRow: false };
    }
    if (lowered === "void") return { plName, type: "jsonb", isRow: false };
    if (typeName.includes(".")) return { plName, type: typeName, isRow: true };
    return { plName, type: "record", isRow: false };
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
      case "assert":
        this.emitAssert(stmt);
        break;
      case "emit":
        throw new Error("emit statements must be lowered before code generation");
      case "try_catch":
        this.emitTryCatch(stmt);
        break;
    }
  }

  private emitTryCatch(stmt: TryCatchStatement): void {
    this.line("BEGIN", stmt.loc);
    this.indent++;
    for (const s of stmt.body) this.emitStatement(s);
    this.indent--;
    this.line("EXCEPTION WHEN OTHERS THEN", stmt.loc);
    this.indent++;
    for (const s of stmt.catchBody) this.emitStatement(s);
    this.indent--;
    this.line("END;", stmt.loc);
  }

  private emitAssert(stmt: AssertStatement): void {
    const msg = stmt.message ?? `assert line ${stmt.loc.line}`;
    const escaped = sqlEscape(msg);
    if (!this.isPgTapFunction()) {
      this.lineFromParts(["IF NOT (", this.emitAssertExpr(stmt.expression), ") THEN"], stmt.loc);
      this.indent++;
      this.line(`RAISE EXCEPTION USING ERRCODE = 'P0400', MESSAGE = 'Bad Request', DETAIL = '${escaped}';`, stmt.loc);
      this.indent--;
      this.line("END IF;", stmt.loc);
      return;
    }
    if (stmt.expression.kind === "binary" && stmt.expression.op === "=") {
      const left = this.emitAssertExpr(stmt.expression.left);
      const right = this.emitAssertExpr(stmt.expression.right);
      this.lineFromParts(["RETURN NEXT is(", left, ", ", right, `, '${escaped}');`], stmt.loc);
    } else if (stmt.expression.kind === "binary" && stmt.expression.op === "IS NULL") {
      const left = this.emitAssertExpr(stmt.expression.left);
      this.lineFromParts(["RETURN NEXT is(", left, ", NULL, ", `'${escaped}');`], stmt.loc);
    } else if (stmt.expression.kind === "binary" && stmt.expression.op === "!=") {
      const left = this.emitAssertExpr(stmt.expression.left);
      const right = this.emitAssertExpr(stmt.expression.right);
      this.lineFromParts(["RETURN NEXT isnt(", left, ", ", right, `, '${escaped}');`], stmt.loc);
    } else {
      this.lineFromParts(["RETURN NEXT ok(", this.emitAssertExpr(stmt.expression), `, '${escaped}');`], stmt.loc);
    }
  }

  private isPgTapFunction(): boolean {
    return this.fn.setof && this.fn.returnType === "text";
  }

  private emitAssign(stmt: AssignStatement): void {
    if (stmt.target === "_") {
      this.lineFromParts(["PERFORM ", this.emitExprMap(stmt.value), ";"], stmt.loc);
      return;
    }
    const varInfo = this.vars.get(stmt.target);
    const plName = varInfo?.plName ?? stmt.target;

    if (stmt.value.kind === "sql_block") {
      this.emitSqlAssign(plName, stmt.value);
      return;
    }
    if (varInfo?.init && this.isInitEquivalent(varInfo.init, stmt.value)) return;
    this.lineFromParts([`${plName} := `, this.emitExprMap(stmt.value), ";"], stmt.loc);
  }

  private isInitEquivalent(init: string, value: Expression): boolean {
    if (value.kind === "array_literal" && value.elements.length === 0 && init === "'[]'::jsonb") return true;
    if (value.kind === "literal" && init === String(value.value)) return true;
    return false;
  }

  private emitSqlAssign(plName: string, sql: SqlBlockExpr): void {
    let sqlText = sql.sql;
    const lowerSql = sqlText.toLowerCase().trim();

    // Parenthesized subquery: (SELECT ...) → unwrap and use SELECT INTO
    if (lowerSql.startsWith("(") && lowerSql.endsWith(")")) {
      const inner = sqlText.slice(1, -1).trim();
      const innerLower = inner.toLowerCase();
      const innerFromMatch = inner.match(SELECT_FROM_RE);
      if (innerFromMatch) {
        const rewritten = `${innerFromMatch[1]}INTO ${plName} ${innerFromMatch[2]}${inner.slice(innerFromMatch[0].length)}`;
        this.line(rewritten + ";", sql.loc);
      } else if (SELECT_NO_FROM_RE.test(innerLower) && !innerLower.includes(" from ")) {
        this.line(`${inner.replace(SELECT_NO_FROM_RE, `$&INTO ${plName} `)};`, sql.loc);
      } else {
        // Fallback: direct assignment for non-SELECT subqueries
        this.line(`${plName} := ${sqlText};`, sql.loc);
      }
      this.emitNotFoundGuard(sql.elseRaise, sql.loc);
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

    this.line(`${sqlText};`, sql.loc);
    this.emitNotFoundGuard(sql.elseRaise, sql.loc);
  }

  private emitNotFoundGuard(msg: string | undefined, loc?: Loc): void {
    if (!msg) return;
    this.line("IF NOT FOUND THEN", loc);
    this.indent++;
    this.line(`RAISE EXCEPTION '${sqlEscape(msg)}';`, loc);
    this.indent--;
    this.line("END IF;", loc);
  }

  private emitAppend(stmt: AppendStatement): void {
    const varInfo = this.vars.get(stmt.target);
    const plName = varInfo?.plName ?? `v_${stmt.target}`;
    this.lineFromParts([`${plName} := ${plName} || `, this.emitExprMap(stmt.value), ";"], stmt.loc);
  }

  private emitIf(stmt: IfStatement): void {
    this.lineFromParts(["IF ", this.emitExprMap(stmt.condition), " THEN"], stmt.loc);
    this.indent++;
    for (const s of stmt.body) this.emitStatement(s);
    this.indent--;
    for (const elsif of stmt.elsifs) {
      this.lineFromParts(["ELSIF ", this.emitExprMap(elsif.condition), " THEN"], elsif.condition.loc);
      this.indent++;
      for (const s of elsif.body) this.emitStatement(s);
      this.indent--;
    }
    if (stmt.elseBody) {
      this.line("ELSE", stmt.loc);
      this.indent++;
      for (const s of stmt.elseBody) this.emitStatement(s);
      this.indent--;
    }
    this.line("END IF;", stmt.loc);
  }

  private emitFor(stmt: ForInStatement): void {
    this.line(`FOR v_${stmt.variable} IN ${stmt.query} LOOP`, stmt.loc);
    this.indent++;
    for (const s of stmt.body) this.emitStatement(s);
    this.indent--;
    this.line("END LOOP;", stmt.loc);
  }

  private emitReturn(stmt: ReturnStatement): void {
    // Bare return — use RETURN for void/setof, RETURN NULL for scalar return types
    if (stmt.value.kind === "literal" && stmt.value.type === "null") {
      if (this.fn.returnType === "void" || this.fn.setof) {
        this.line("RETURN;", stmt.loc);
      } else {
        this.line("RETURN NULL;", stmt.loc);
      }
      return;
    }

    // return query → RETURN QUERY
    if (stmt.mode === "query") {
      this.lineFromParts(["RETURN QUERY ", this.emitExprMap(stmt.value), ";"], stmt.loc);
      return;
    }

    // return execute → RETURN QUERY EXECUTE
    if (stmt.mode === "execute") {
      this.lineFromParts(["RETURN QUERY EXECUTE ", this.emitExprMap(stmt.value), ";"], stmt.loc);
      return;
    }

    // yield / setof → RETURN NEXT
    if (stmt.isYield || this.fn.setof) {
      if (stmt.value.kind === "sql_block") {
        this.line(`RETURN QUERY ${stmt.value.sql};`, stmt.loc);
      } else {
        this.lineFromParts(["RETURN NEXT ", this.emitExprMap(stmt.value), ";"], stmt.loc);
      }
      return;
    }

    if (stmt.value.kind === "sql_block") {
      this.line(`RETURN (${stmt.value.sql});`, stmt.loc);
      return;
    }

    this.lineFromParts(["RETURN ", this.emitExprMap(stmt.value), ";"], stmt.loc);
  }

  private emitAssertExpr(expr: Expression): MappedText {
    const mapped = this.emitExprMap(expr);
    if (expr.kind !== "sql_block") return mapped;
    return withContainerSegment(concatMapped(["(", mapped, ")"]), expr.loc);
  }

  private emitRaise(stmt: RaiseStatement): void {
    this.line(`RAISE EXCEPTION '${sqlEscape(stmt.message)}';`, stmt.loc);
  }

  private emitMatch(stmt: MatchStatement): void {
    this.lineFromParts(["CASE ", this.emitExprMap(stmt.subject)], stmt.loc);
    this.indent++;
    for (const arm of stmt.arms) {
      this.lineFromParts(["WHEN ", this.emitExprMap(arm.pattern), " THEN"], arm.pattern.loc);
      this.indent++;
      for (const s of arm.body) this.emitStatement(s);
      this.indent--;
    }
    if (stmt.elseBody) {
      this.line("ELSE", stmt.loc);
      this.indent++;
      for (const s of stmt.elseBody) this.emitStatement(s);
      this.indent--;
    }
    this.indent--;
    this.line("END CASE;", stmt.loc);
  }

  private emitSqlStatement(stmt: SqlStatement): void {
    this.line(`${stmt.sql};`, stmt.loc);
  }

  // ---------- Expression emission ----------

  private emitExpr(expr: Expression): string {
    return this.emitExprMap(expr).text;
  }

  private emitExprMap(expr: Expression): MappedText {
    switch (expr.kind) {
      case "sql_block":
        return { text: expr.sql, segments: [segmentForText(expr.sql, expr.loc)] };
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
      case "group":
        return this.emitGroup(expr);
      case "unary":
        return this.emitUnary(expr);
      case "binary":
        return this.emitBinary(expr);
      case "call":
        return this.emitCall(expr);
      case "case_expr":
        return this.emitCaseExpr(expr);
    }
  }

  private emitJson(json: JsonLiteral): MappedText {
    if (json.entries.length === 0) return mappedLiteral("'{}'::jsonb", json.loc);
    const parts: (string | MappedText)[] = ["jsonb_build_object("];
    json.entries.forEach((entry, index) => {
      if (index > 0) parts.push(", ");
      parts.push(`'${entry.key}', `);
      parts.push(this.emitJsonValue(entry.value));
    });
    parts.push(")");
    return withContainerSegment(concatMapped(parts), json.loc);
  }

  private emitJsonValue(expr: Expression): MappedText {
    if (expr.kind === "identifier") {
      const varInfo = this.vars.get(expr.name);
      if (varInfo?.isRow)
        return withContainerSegment(mappedLiteral(`row_to_json(${varInfo.plName})::jsonb`, expr.loc), expr.loc);
      return this.emitIdent(expr);
    }
    return this.emitExprMap(expr);
  }

  private emitArray(arr: ArrayLiteral): MappedText {
    if (arr.elements.length === 0) return mappedLiteral("'[]'::jsonb", arr.loc);
    const parts: (string | MappedText)[] = ["jsonb_build_array("];
    arr.elements.forEach((element, index) => {
      if (index > 0) parts.push(", ");
      parts.push(this.emitExprMap(element));
    });
    parts.push(")");
    return withContainerSegment(concatMapped(parts), arr.loc);
  }

  private emitInterp(interp: StringInterp): MappedText {
    const parts: (string | MappedText)[] = [];
    interp.parts.forEach((part, index) => {
      if (index > 0) parts.push(" || ");
      parts.push(typeof part === "string" ? `'${sqlEscape(part)}'` : this.emitExprMap(part));
    });
    return withContainerSegment(concatMapped(parts), interp.loc);
  }

  private emitFieldAccess(fa: FieldAccess): MappedText {
    return mappedLiteral(`${this.resolveVarName(fa.object)}.${fa.field}`, fa.loc);
  }

  private emitIdent(id: Identifier): MappedText {
    return mappedLiteral(this.resolveVarName(id.name), id.loc);
  }

  private emitGroup(group: GroupExpr): MappedText {
    return withContainerSegment(concatMapped(["(", this.emitExprMap(group.expression), ")"]), group.loc);
  }

  private emitUnary(unary: UnaryExpr): MappedText {
    const precedence = unaryPrecedence(unary.op);
    const expression = this.emitNestedExpr(unary.expression, precedence, "right", "right");
    if (unary.op === "NOT") return withContainerSegment(concatMapped(["NOT ", expression]), unary.loc);
    return withContainerSegment(concatMapped([unary.op, expression]), unary.loc);
  }

  private emitIsNullCheck(expr: Expression, side: "left" | "right", negated: boolean, loc: Loc): MappedText {
    return withContainerSegment(
      concatMapped([this.emitNestedExpr(expr, 30, side, "left"), negated ? " IS NOT NULL" : " IS NULL"]),
      loc,
    );
  }

  private emitBinary(bin: BinaryExpr): MappedText {
    if (bin.op === "IS NULL") return this.emitIsNullCheck(bin.left, "left", false, bin.loc);
    if (bin.op === "IS NOT NULL") return this.emitIsNullCheck(bin.left, "left", true, bin.loc);
    // x = null → x IS NULL, x != null → x IS NOT NULL (SQL three-valued logic)
    if (isNullExpr(bin.right)) {
      if (bin.op === "=") return this.emitIsNullCheck(bin.left, "left", false, bin.loc);
      if (bin.op === "!=") return this.emitIsNullCheck(bin.left, "left", true, bin.loc);
    }
    if (isNullExpr(bin.left)) {
      if (bin.op === "=") return this.emitIsNullCheck(bin.right, "right", false, bin.loc);
      if (bin.op === "!=") return this.emitIsNullCheck(bin.right, "right", true, bin.loc);
    }
    const { precedence, assoc } = binaryPrecedence(bin.op);
    const left = this.emitNestedExpr(bin.left, precedence, "left", assoc);
    if (bin.op === "IN" && bin.right.kind === "array_literal") {
      const items: (string | MappedText)[] = [];
      bin.right.elements.forEach((element, index) => {
        if (index > 0) items.push(", ");
        items.push(this.emitExprMap(element));
      });
      return withContainerSegment(concatMapped([left, " IN (", ...items, ")"]), bin.loc);
    }
    const right = this.emitNestedExpr(bin.right, precedence, "right", assoc);
    if (bin.op === "::") return withContainerSegment(concatMapped([left, "::", right]), bin.loc);
    if (bin.op === "->>" || bin.op === "->") return withContainerSegment(concatMapped([left, bin.op, right]), bin.loc);
    return withContainerSegment(concatMapped([left, ` ${bin.op} `, right]), bin.loc);
  }

  private emitCall(call: CallExpr): MappedText {
    const name = this.aliases.get(call.name) ?? call.name;
    const parts: (string | MappedText)[] = [`${name}(`];
    call.args.forEach((arg, index) => {
      if (index > 0) parts.push(", ");
      parts.push(this.emitExprMap(arg));
    });
    parts.push(")");
    return withContainerSegment(concatMapped(parts), call.loc);
  }

  private emitCaseExpr(c: CaseExpr): MappedText {
    const parts: (string | MappedText)[] = ["CASE ", this.emitExprMap(c.subject)];
    for (const arm of c.arms) {
      parts.push(" WHEN ", this.emitExprMap(arm.pattern), " THEN ", this.emitExprMap(arm.result));
    }
    if (c.elseResult) {
      parts.push(" ELSE ", this.emitExprMap(c.elseResult));
    }
    parts.push(" END");
    return withContainerSegment(concatMapped(parts), c.loc);
  }

  // ---------- Helpers ----------

  private resolveVarName(name: string): string {
    if (this.paramNames.has(name)) return name;
    const v = this.vars.get(name);
    return v ? v.plName : name;
  }

  private line(text: string, loc?: Loc, segments: SourceSegment[] = []): void {
    const indentText = INDENTS[this.indent] ?? "  ".repeat(this.indent);
    const shiftedSegments = segments.map((segment) => ({
      ...segment,
      startCol: segment.startCol + indentText.length,
      endCol: segment.endCol + indentText.length,
    }));
    for (const lineText of text.split("\n")) {
      this.lines.push({
        text: `${indentText}${lineText}`,
        loc,
        segments: lineText === text ? shiftedSegments : [],
      });
    }
  }

  private lineFromParts(parts: (string | MappedText)[], loc?: Loc): void {
    const mapped = concatMapped(parts);
    this.line(mapped.text, loc, mapped.segments);
  }

  private emitNestedExpr(expr: Expression, parentPrecedence: number, side: "left" | "right", assoc: Assoc): MappedText {
    if (expr.kind === "group") return this.emitExprMap(expr);
    const rendered = this.emitExprMap(expr);
    const childPrecedence = expressionPrecedence(expr);
    const equalNeedsParens =
      expr.kind === "binary" &&
      childPrecedence === parentPrecedence &&
      ((assoc === "left" && side === "right") || (assoc === "right" && side === "left"));

    if (childPrecedence < parentPrecedence || equalNeedsParens) {
      return concatMapped(["(", rendered, ")"]);
    }

    return rendered;
  }
}

function isNullExpr(expr: Expression): boolean {
  if (expr.kind === "literal" && expr.type === "null") return true;
  if (expr.kind === "identifier" && expr.name === "null") return true;
  return false;
}

function emitLiteral(lit: Literal): MappedText {
  if (lit.type === "text") return mappedLiteral(`'${sqlEscape(String(lit.value))}'`, lit.loc);
  if (lit.type === "null") return mappedLiteral("NULL", lit.loc);
  return mappedLiteral(String(lit.value), lit.loc);
}

function unaryPrecedence(op: UnaryExpr["op"]): number {
  if (op === "NOT") return 90;
  return 90;
}

function binaryPrecedence(op: string): { precedence: number; assoc: Assoc } {
  switch (op) {
    case "OR":
      return { precedence: 10, assoc: "left" };
    case "AND":
      return { precedence: 20, assoc: "left" };
    case "=":
    case "!=":
    case ">":
    case "<":
    case ">=":
    case "<=":
    case "IN":
    case "IS NULL":
    case "IS NOT NULL":
      return { precedence: 30, assoc: "left" };
    case "||":
      return { precedence: 40, assoc: "left" };
    case "+":
    case "-":
      return { precedence: 50, assoc: "left" };
    case "*":
    case "/":
      return { precedence: 60, assoc: "left" };
    case "->":
    case "->>":
      return { precedence: 70, assoc: "left" };
    case "::":
      return { precedence: 80, assoc: "right" };
    default:
      return { precedence: 30, assoc: "left" };
  }
}

function expressionPrecedence(expr: Expression): number {
  switch (expr.kind) {
    case "group":
      return PRIMARY_PRECEDENCE;
    case "unary":
      return unaryPrecedence(expr.op);
    case "binary":
      return binaryPrecedence(expr.op).precedence;
    case "case_expr":
      return 5;
    default:
      return PRIMARY_PRECEDENCE;
  }
}

function formatParam(p: Param): string {
  let s = `${p.name} ${p.type}`;
  if (p.defaultValue !== undefined) s += ` DEFAULT ${p.defaultValue}`;
  return s;
}

function concatMapped(parts: (string | MappedText)[]): MappedText {
  let text = "";
  const segments: SourceSegment[] = [];

  for (const part of parts) {
    if (typeof part === "string") {
      text += part;
      continue;
    }

    const offset = text.length;
    text += part.text;
    for (const segment of part.segments) {
      segments.push({
        ...segment,
        startCol: segment.startCol + offset,
        endCol: segment.endCol + offset,
      });
    }
  }

  return { text, segments };
}

function mappedLiteral(text: string, loc: Loc): MappedText {
  return {
    text,
    segments: [segmentForText(text, loc)],
  };
}

function withContainerSegment(mapped: MappedText, loc: Loc): MappedText {
  return {
    text: mapped.text,
    segments: [segmentForText(mapped.text, loc), ...mapped.segments],
  };
}

function segmentForText(text: string, loc: Loc): SourceSegment {
  return {
    startCol: 0,
    endCol: text.length,
    loc,
    text,
  };
}
