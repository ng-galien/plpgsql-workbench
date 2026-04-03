// PLX Parse Context — Core parsing engine (token navigation, expressions, statements, utilities)

import type {
  AppendStatement,
  ArrayLiteral,
  AssertStatement,
  AssignStatement,
  CaseExpr,
  EmitStatement,
  Expression,
  ForInStatement,
  GroupExpr,
  IfStatement,
  JsonLiteral,
  Loc,
  MatchStatement,
  RaiseStatement,
  ReturnMode,
  ReturnStatement,
  SqlBlockExpr,
  SqlStatement,
  Statement,
  StringInterp,
  TryCatchStatement,
  UnaryExpr,
} from "./ast.js";
import { mergeLoc, pointLoc, shiftLoc, stripLocPrefix } from "./ast.js";
import { LexError, type Token, type TokenType, tokenize } from "./lexer.js";

// Hoisted regexes for parseSqlBlock
const ELSE_RAISE_RE = /\nelse\s+raise\s+['"](.*?)['"]\s*$/i;
const TABLE_INFER_RE = /select\s+\*\s+from\s+(\w+\.\w+)/i;

type Assoc = "left" | "right";

interface BinaryOpInfo {
  op: string;
  precedence: number;
  assoc: Assoc;
}

export class ParseError extends Error {
  code: string;
  hint?: string;

  constructor(
    msg: string,
    public loc: Loc,
    options?: {
      code?: string;
      hint?: string;
    },
  ) {
    super(`plx:${loc.line}:${loc.col}: ${msg}`);
    this.code = options?.code ?? "parse.invalid-syntax";
    this.hint = options?.hint;
  }
}

export class ParseContext {
  pos = 0;

  constructor(public tokens: Token[]) {}

  // ---------- Token navigation ----------

  peek(): Token {
    return this.tokens[this.pos] ?? { type: "EOF" as const, value: "", line: 0, col: 0, endLine: 0, endCol: 0 };
  }

  peekAt(offset: number): Token | undefined {
    return this.tokens[this.pos + offset];
  }

  loc(): Loc {
    return tokenLoc(this.peek());
  }

  isAt(type: TokenType): boolean {
    return this.peek().type === type;
  }

  advance(): Token {
    const t = this.peek();
    this.pos++;
    return t;
  }

  expect(...types: TokenType[]): Token {
    const tok = this.peek();
    if (types.length === 1 ? tok.type !== types[0] : !types.includes(tok.type)) {
      throw new ParseError(
        `expected ${types.join(" or ")}, got ${tok.type} '${tok.value}'`,
        {
          line: tok.line,
          col: tok.col,
          endLine: tok.endLine,
          endCol: tok.endCol,
        },
        {
          code: "parse.unexpected-token",
          hint: `Expected ${types.join(" or ")} at this position.`,
        },
      );
    }
    return this.advance();
  }

  skipNewlines(): void {
    while (this.peek().type === "NEWLINE") this.pos++;
  }

  /** Skip NEWLINE + INDENT + DEDENT — for multi-line expressions inside parens/case */
  skipExprWs(): void {
    while (this.peek().type === "NEWLINE" || this.peek().type === "INDENT" || this.peek().type === "DEDENT") {
      this.pos++;
    }
  }

  /** Skip expression-internal whitespace without consuming block-closing DEDENT. */
  skipInlineExprWs(): void {
    while (this.peek().type === "NEWLINE" || this.peek().type === "INDENT") {
      this.pos++;
    }
  }

  // ---------- Shared utilities ----------

  /** Parse "ident" or "ident.ident" as a qualified name string */
  parseQualifiedName(): string {
    let name = this.expect("IDENT").value;
    if (this.isAt("DOT")) {
      this.advance();
      name += `.${this.expect("IDENT").value}`;
    }
    return name;
  }

  /** Parse a value that can be STRING or qualified IDENT (for brace KV objects) */
  parseQualifiedValue(): string {
    let v = this.expect("IDENT", "STRING").value;
    if (this.isAt("DOT")) {
      this.advance();
      v += `.${this.expect("IDENT").value}`;
    }
    return v;
  }

  /** Parse an indented block of items: INDENT item* DEDENT */
  parseIndentedList<T>(parseItem: () => T): T[] {
    this.skipNewlines();
    this.expect("INDENT");
    const items: T[] = [];
    while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
      this.skipNewlines();
      if (this.isAt("DEDENT")) break;
      items.push(parseItem());
      this.skipNewlines();
    }
    this.expect("DEDENT");
    return items;
  }

  // ---------- Statement parsing ----------

  parseBlock(): Statement[] {
    const stmts: Statement[] = [];
    this.skipNewlines();
    while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
      stmts.push(this.parseStatement());
      this.skipNewlines();
    }
    return stmts;
  }

  parseStatement(): Statement {
    const tok = this.peek();

    if (tok.type === "IF") return this.parseIf();
    if (tok.type === "FOR") return this.parseFor();
    if (tok.type === "RETURN") return this.parseReturn();
    if (tok.type === "YIELD") return this.parseYield();
    if (tok.type === "RAISE") return this.parseRaise();
    if (tok.type === "MATCH") return this.parseMatch();
    if (tok.type === "ASSERT") return this.parseAssert();
    if (tok.type === "SQL_BLOCK") return this.parseSqlStatement();

    if (tok.type === "IDENT") {
      if (tok.value === "try") return this.parseTryCatch();
      if (tok.value === "emit") return this.parseEmit();
      const next = this.peekAt(1);
      if (next?.type === "ASSIGN") return this.parseAssign();
      if (next?.type === "APPEND") return this.parseAppend();
    }

    const expr = this.parseExpression();
    this.skipNewlines();
    return { kind: "assign", target: "_", value: expr, loc: expr.loc } as AssignStatement;
  }

  private parseEmit(): EmitStatement {
    const start = tokenLoc(this.expect("IDENT"));
    let eventName = this.expect("IDENT").value;
    while (this.isAt("DOT")) {
      this.advance();
      eventName += `.${this.expect("IDENT").value}`;
    }
    this.expect("LPAREN");
    const args: Expression[] = [];
    if (!this.isAt("RPAREN")) {
      args.push(this.parseExpression());
      while (this.isAt("COMMA")) {
        this.advance();
        args.push(this.parseExpression());
      }
    }
    const end = tokenLoc(this.expect("RPAREN"));
    this.skipNewlines();
    return { kind: "emit", eventName, args, loc: mergeLoc(start, end) };
  }

  private parseAssign(): AssignStatement {
    const targetTok = this.expect("IDENT");
    const loc = tokenLoc(targetTok);
    const target = targetTok.value;
    this.expect("ASSIGN");

    if (this.isAt("SQL_BLOCK")) {
      const sqlTok = this.advance();
      const value = parseSqlBlock(sqlTok);
      this.skipNewlines();
      return { kind: "assign", target, value, loc: mergeLoc(loc, value.loc) };
    }

    const value = this.parseExpression();
    this.skipNewlines();
    return { kind: "assign", target, value, loc: mergeLoc(loc, value.loc) };
  }

  private parseAppend(): AppendStatement {
    const targetTok = this.expect("IDENT");
    const loc = tokenLoc(targetTok);
    const target = targetTok.value;
    this.expect("APPEND");
    const value = this.parseExpression();
    this.skipNewlines();
    return { kind: "append", target, value, loc: mergeLoc(loc, value.loc) };
  }

  private parseIf(): IfStatement {
    const start = tokenLoc(this.expect("IF"));
    const condition = this.parseExpression();
    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");
    const body = this.parseBlock();
    let end = tokenLoc(this.expect("DEDENT"));
    this.skipNewlines();

    const elsifs: { condition: Expression; body: Statement[] }[] = [];
    while (this.isAt("ELSIF")) {
      this.advance();
      const elsifCond = this.parseExpression();
      this.expect("COLON");
      this.skipNewlines();
      this.expect("INDENT");
      const elsifBody = this.parseBlock();
      end = tokenLoc(this.expect("DEDENT"));
      this.skipNewlines();
      elsifs.push({ condition: elsifCond, body: elsifBody });
    }

    let elseBody: Statement[] | undefined;
    if (this.isAt("ELSE")) {
      this.advance();
      this.expect("COLON");
      this.skipNewlines();
      this.expect("INDENT");
      elseBody = this.parseBlock();
      end = tokenLoc(this.expect("DEDENT"));
      this.skipNewlines();
    }

    return { kind: "if", condition, body, elsifs, elseBody, loc: mergeLoc(start, end) };
  }

  private parseFor(): ForInStatement {
    const start = tokenLoc(this.expect("FOR"));
    const variableTok = this.expect("IDENT");
    const variable = variableTok.value;
    this.expect("IN");

    if (this.isAt("SQL_BLOCK")) {
      const sqlTok = this.advance();
      this.expect("COLON");
      this.skipNewlines();
      this.expect("INDENT");
      const body = this.parseBlock();
      const end = tokenLoc(this.expect("DEDENT"));
      return { kind: "for_in", variable, query: sqlTok.value, body, loc: mergeLoc(start, end) };
    }

    // Fallback: collect tokens until ":"
    const parts: string[] = [];
    while (!this.isAt("COLON") && !this.isAt("EOF")) {
      parts.push(this.advance().value);
    }
    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");
    const body = this.parseBlock();
    const end = tokenLoc(this.expect("DEDENT"));

    return { kind: "for_in", variable, query: parts.join(" "), body, loc: mergeLoc(start, end) };
  }

  private parseTryCatch(): TryCatchStatement {
    const start = tokenLoc(this.expect("IDENT")); // consume "try"
    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");
    const body = this.parseBlock();
    this.expect("DEDENT");
    this.skipNewlines();

    // Expect "catch:"
    const catchTok = this.peek();
    if (catchTok.type !== "IDENT" || catchTok.value !== "catch") {
      throw new ParseError("expected 'catch' after try block", tokenLoc(catchTok), {
        code: "parse.expected-catch",
        hint: "A try block must be followed by a catch block.",
      });
    }
    this.advance();
    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");
    const catchBody = this.parseBlock();
    const end = tokenLoc(this.expect("DEDENT"));
    this.skipNewlines();

    return { kind: "try_catch", body, catchBody, loc: mergeLoc(start, end) };
  }

  private parseReturn(): ReturnStatement {
    const start = tokenLoc(this.expect("RETURN"));

    // Bare return
    if (this.isAt("NEWLINE") || this.isAt("DEDENT") || this.isAt("EOF")) {
      return {
        kind: "return",
        value: { kind: "literal", value: null, type: "null", loc: start },
        isYield: false,
        mode: "value",
        loc: start,
      };
    }

    if (this.isAt("IDENT") && (this.peek().value === "query" || this.peek().value === "execute")) {
      const legacy = this.advance();
      throw new ParseError(`legacy return mode '${legacy.value}' is not supported in target syntax`, tokenLoc(legacy), {
        code: "parse.legacy-return-mode",
        hint: 'Use `return expr` or `return """ ... """` instead.',
      });
    }

    if (this.isAt("SQL_BLOCK")) {
      const sqlTok = this.advance();
      this.skipNewlines();
      const value = parseSqlBlock(sqlTok);
      return {
        kind: "return",
        value,
        isYield: false,
        mode: "value",
        loc: mergeLoc(start, value.loc),
      };
    }

    const value = this.parseExpression();
    this.skipNewlines();
    return { kind: "return", value, isYield: false, mode: "value", loc: mergeLoc(start, value.loc) };
  }

  private parseYield(): ReturnStatement {
    const start = tokenLoc(this.expect("YIELD"));
    const value = this.parseExpression();
    this.skipNewlines();
    return { kind: "return", value, isYield: true, mode: "value", loc: mergeLoc(start, value.loc) };
  }

  private parseRaise(): RaiseStatement {
    const start = tokenLoc(this.expect("RAISE"));
    const msgTok = this.expect("STRING");
    this.skipNewlines();
    return { kind: "raise", message: msgTok.value, loc: mergeLoc(start, tokenLoc(msgTok)) };
  }

  private parseMatch(): MatchStatement {
    const start = tokenLoc(this.expect("MATCH"));
    const subject = this.parseExpression();
    this.expect("COLON");
    this.skipNewlines();
    this.expect("INDENT");

    const arms: { pattern: Expression; body: Statement[] }[] = [];
    let elseBody: Statement[] | undefined;
    let end = subject.loc;

    while (!this.isAt("DEDENT") && !this.isAt("EOF")) {
      this.skipNewlines();
      if (this.isAt("DEDENT") || this.isAt("EOF")) break;

      if (this.isAt("ELSE")) {
        this.advance();
        this.expect("COLON", "ARROW");
        this.skipNewlines();
        this.expect("INDENT");
        elseBody = this.parseBlock();
        end = tokenLoc(this.expect("DEDENT"));
      } else {
        const pattern = this.parseExpression();
        this.expect("COLON", "ARROW");
        this.skipNewlines();
        this.expect("INDENT");
        const body = this.parseBlock();
        end = tokenLoc(this.expect("DEDENT"));
        arms.push({ pattern, body });
      }
      this.skipNewlines();
    }

    end = tokenLoc(this.expect("DEDENT"));
    return { kind: "match", subject, arms, elseBody, loc: mergeLoc(start, end) };
  }

  private parseAssert(): AssertStatement {
    const start = tokenLoc(this.expect("ASSERT"));
    const expression = this.isAt("SQL_BLOCK") ? parseSqlBlock(this.advance()) : this.parseExpression();
    let message: string | undefined;
    let end = expression.loc;
    if (this.isAt("COMMA")) {
      this.advance();
      message = this.parseQualifiedValue();
      end = this.loc();
    }
    this.skipNewlines();
    return { kind: "assert", expression, message, loc: mergeLoc(start, end) };
  }

  private parseSqlStatement(): SqlStatement {
    const tok = this.advance();
    this.skipNewlines();
    return { kind: "sql_statement", sql: tok.value, loc: tokenLoc(tok) };
  }

  // ---------- Expression parsing ----------

  parseExpression(minPrecedence = 0): Expression {
    this.skipInlineExprWs();
    let left = this.parsePrefix();

    while (true) {
      this.skipInlineExprWs();

      // Postfix: IS NULL / IS NOT NULL
      const isNull = this.peekIsNull();
      if (isNull && 30 >= minPrecedence) {
        for (let i = 0; i < isNull.tokens; i++) this.advance();
        const nullLit: Expression = { kind: "literal", value: null, type: "null", loc: left.loc };
        left = {
          kind: "binary",
          op: isNull.negated ? "IS NOT NULL" : "IS NULL",
          left,
          right: nullLit,
          loc: left.loc,
        };
        continue;
      }

      const opInfo = this.peekBinaryOperator();
      if (!opInfo || opInfo.precedence < minPrecedence) break;

      this.advanceBinaryOperator(opInfo);
      const nextMin = opInfo.assoc === "right" ? opInfo.precedence : opInfo.precedence + 1;
      const right = this.parseExpression(nextMin);
      left = { kind: "binary", op: opInfo.op, left, right, loc: mergeLoc(left.loc, right.loc) };
    }

    return left;
  }

  /** Peek for `is null` (2 tokens) or `is not null` (3 tokens). */
  private peekIsNull(): { negated: boolean; tokens: number } | undefined {
    const tok = this.peek();
    if (tok.type !== "IDENT" || tok.value !== "is") return undefined;
    const t1 = this.peekAt(1);
    if (!t1) return undefined;
    // is null
    if (t1.type === "IDENT" && t1.value === "null") return { negated: false, tokens: 2 };
    // is not null
    if (t1.type === "NOT") {
      const t2 = this.peekAt(2);
      if (t2 && t2.type === "IDENT" && t2.value === "null") return { negated: true, tokens: 3 };
    }
    return undefined;
  }

  private parsePrefix(): Expression {
    this.skipInlineExprWs();
    const tok = this.peek();

    if (tok.type === "NOT") {
      this.advance();
      const expression = this.parseExpression(UNARY_PRECEDENCE);
      return { kind: "unary", op: "NOT", expression, loc: mergeLoc(tokenLoc(tok), expression.loc) } as UnaryExpr;
    }

    if (tok.type === "OPERATOR" && (tok.value === "+" || tok.value === "-")) {
      this.advance();
      const expression = this.parseExpression(UNARY_PRECEDENCE);
      return { kind: "unary", op: tok.value, expression, loc: mergeLoc(tokenLoc(tok), expression.loc) } as UnaryExpr;
    }

    return this.parsePrimary();
  }

  private parsePrimary(): Expression {
    this.skipInlineExprWs();
    const tok = this.peek();

    if (tok.type === "CASE") return this.parseCaseExpr();
    if (tok.type === "LBRACE") return this.parseJsonLiteral();
    if (tok.type === "LBRACKET") return this.parseArrayLiteral();
    if (tok.type === "INTERP_STRING") return this.parseInterpString();

    if (tok.type === "STRING") {
      this.advance();
      return { kind: "literal", value: tok.value, type: "text", loc: tokenLoc(tok) };
    }

    if (tok.type === "NUMBER") {
      this.advance();
      if (tok.value === "true" || tok.value === "false") {
        return { kind: "literal", value: tok.value === "true", type: "boolean", loc: tokenLoc(tok) };
      }
      return { kind: "literal", value: Number(tok.value), type: "int", loc: tokenLoc(tok) };
    }

    if (tok.type === "IDENT") {
      this.advance();
      const loc = tokenLoc(tok);

      if (this.isAt("DOT")) {
        this.advance();
        const secondTok = this.expect("IDENT");
        const second = secondTok.value;
        let currentLoc = mergeLoc(loc, tokenLoc(secondTok));

        // schema.func(args)
        if (this.isAt("LPAREN")) {
          const args = this.parseArgList();
          const end = args.at(-1)?.loc ?? currentLoc;
          return { kind: "call", name: `${tok.value}.${second}`, args, loc: mergeLoc(loc, end) };
        }

        // ident.field.subfield
        if (this.isAt("DOT")) {
          this.advance();
          const subfieldTok = this.expect("IDENT");
          const subfield = subfieldTok.value;
          currentLoc = mergeLoc(currentLoc, tokenLoc(subfieldTok));
          const fa: Expression = {
            kind: "field_access",
            object: `${tok.value}.${second}`,
            field: subfield,
            loc: currentLoc,
          };
          if (this.isAt("QUESTION")) {
            const questionTok = this.advance();
            return nullCheck(fa, mergeLoc(currentLoc, tokenLoc(questionTok)));
          }
          return fa;
        }

        // ident.field?
        if (this.isAt("QUESTION")) {
          const questionTok = this.advance();
          return nullCheck(
            { kind: "field_access", object: tok.value, field: second, loc: currentLoc },
            mergeLoc(currentLoc, tokenLoc(questionTok)),
          );
        }

        return { kind: "field_access", object: tok.value, field: second, loc: currentLoc };
      }

      // func(args)
      if (this.isAt("LPAREN")) {
        const args = this.parseArgList();
        const end = args.at(-1)?.loc ?? loc;
        return { kind: "call", name: tok.value, args, loc: mergeLoc(loc, end) };
      }

      // ident?
      if (this.isAt("QUESTION")) {
        const questionTok = this.advance();
        return nullCheck({ kind: "identifier", name: tok.value, loc }, mergeLoc(loc, tokenLoc(questionTok)));
      }

      return { kind: "identifier", name: tok.value, loc };
    }

    if (tok.type === "LPAREN") {
      const start = tokenLoc(tok);
      this.advance();
      const expr = this.parseExpression();
      const end = tokenLoc(this.expect("RPAREN"));
      return { kind: "group", expression: expr, loc: mergeLoc(start, end) } as GroupExpr;
    }

    throw new ParseError(`unexpected token: ${tok.type} '${tok.value}'`, tokenLoc(tok), {
      code: "parse.unexpected-token",
      hint: "Check for a missing operator, closing delimiter, or misplaced keyword.",
    });
  }

  /** Parse CASE expr WHEN val THEN result ... ELSE result END */
  private parseCaseExpr(): CaseExpr {
    const start = tokenLoc(this.expect("CASE"));
    const subject = this.parseExpression();
    this.skipExprWs();

    const arms: { pattern: Expression; result: Expression }[] = [];
    let elseResult: Expression | undefined;

    while (this.isAt("WHEN")) {
      this.advance();
      const pattern = this.parseExpression();
      this.expect("THEN");
      const result = this.parseExpression();
      arms.push({ pattern, result });
      this.skipExprWs();
    }

    if (this.isAt("ELSE")) {
      this.advance();
      elseResult = this.parseExpression();
      this.skipExprWs();
    }

    const end = tokenLoc(this.expect("END"));
    return { kind: "case_expr", subject, arms, elseResult, loc: mergeLoc(start, end) };
  }

  parseArgList(): Expression[] {
    this.expect("LPAREN");
    this.skipExprWs();
    const args: Expression[] = [];
    if (!this.isAt("RPAREN")) {
      args.push(this.parseExpression());
      this.skipExprWs();
      while (this.isAt("COMMA")) {
        this.advance();
        this.skipExprWs();
        args.push(this.parseExpression());
        this.skipExprWs();
      }
    }
    this.skipExprWs();
    this.expect("RPAREN");
    return args;
  }

  private parseJsonLiteral(): JsonLiteral {
    const start = tokenLoc(this.expect("LBRACE"));
    const entries: { key: string; value: Expression }[] = [];

    if (!this.isAt("RBRACE")) {
      entries.push(this.parseJsonEntry());
      while (this.isAt("COMMA")) {
        this.advance();
        if (this.isAt("RBRACE")) break;
        entries.push(this.parseJsonEntry());
      }
    }

    const end = tokenLoc(this.expect("RBRACE"));
    return { kind: "json_literal", entries, loc: mergeLoc(start, end) };
  }

  private parseJsonEntry(): { key: string; value: Expression } {
    const keyTok = this.expect("IDENT");
    const key = keyTok.value;
    if (!this.isAt("COLON")) {
      return { key, value: { kind: "identifier", name: key, loc: tokenLoc(keyTok) } };
    }
    this.expect("COLON");
    return { key, value: this.parseExpression() };
  }

  private parseArrayLiteral(): ArrayLiteral {
    const start = tokenLoc(this.expect("LBRACKET"));
    const elements: Expression[] = [];
    if (!this.isAt("RBRACKET")) {
      elements.push(this.parseExpression());
      while (this.isAt("COMMA")) {
        this.advance();
        elements.push(this.parseExpression());
      }
    }
    const end = tokenLoc(this.expect("RBRACKET"));
    return { kind: "array_literal", elements, loc: mergeLoc(start, end) };
  }

  private parseInterpString(): StringInterp {
    const tok = this.advance();
    const loc = tokenLoc(tok);
    const parts: (string | Expression)[] = [];
    const raw = tok.value;

    let i = 0;
    let current = "";
    while (i < raw.length) {
      if (raw[i] === "#" && raw[i + 1] === "{") {
        if (current) {
          parts.push(current);
          current = "";
        }
        const parsed = parseInterpolatedExpression(raw, i + 2, loc);
        parts.push(parsed.expression);
        i = parsed.nextIndex;
      } else {
        current += raw[i];
        i++;
      }
    }
    if (current) parts.push(current);

    return { kind: "string_interp", parts, loc };
  }

  peekBinaryOperator(): BinaryOpInfo | undefined {
    const tok = this.peek();
    let offset = 1;
    let next = this.peekAt(offset);
    while (next && (next.type === "NEWLINE" || next.type === "INDENT" || next.type === "DEDENT")) {
      offset++;
      next = this.peekAt(offset);
    }
    return binaryOpInfo(tok, next);
  }

  advanceBinaryOperator(opInfo: BinaryOpInfo): void {
    if (this.peek().type === "IDENT" && (opInfo.op === "AND" || opInfo.op === "OR")) {
      this.advance();
      return;
    }
    this.advance();
  }
}

const UNARY_PRECEDENCE = 90;

function isExprStartToken(tok: Token | undefined): boolean {
  if (!tok) return false;
  return (
    tok.type === "IDENT" ||
    tok.type === "NUMBER" ||
    tok.type === "STRING" ||
    tok.type === "INTERP_STRING" ||
    tok.type === "LPAREN" ||
    tok.type === "LBRACE" ||
    tok.type === "LBRACKET" ||
    tok.type === "CASE" ||
    tok.type === "NOT" ||
    (tok.type === "OPERATOR" && (tok.value === "+" || tok.value === "-"))
  );
}

function parseInterpolatedExpression(
  raw: string,
  start: number,
  loc: Loc,
): { expression: Expression; nextIndex: number } {
  let i = start;
  let depth = 1;
  let quote: "'" | '"' | null = null;
  let expr = "";

  while (i < raw.length && depth > 0) {
    const ch = raw[i];
    if (ch === undefined) break;

    if (quote) {
      expr += ch;
      if (ch === quote) {
        if (quote === "'" && raw[i + 1] === "'") {
          expr += "'";
          i += 2;
          continue;
        }
        quote = null;
      }
      i++;
      continue;
    }

    if (ch === "'" || ch === '"') {
      quote = ch;
      expr += ch;
      i++;
      continue;
    }

    if (ch === "{") {
      depth++;
      expr += ch;
      i++;
      continue;
    }

    if (ch === "}") {
      depth--;
      if (depth === 0) {
        i++;
        break;
      }
      expr += ch;
      i++;
      continue;
    }

    expr += ch;
    i++;
  }

  const interpolationLoc = {
    line: loc.line,
    col: loc.col + start - 1,
    endLine: loc.line,
    endCol: loc.col + start + 1,
  };

  if (depth !== 0) {
    throw new ParseError("unterminated interpolation", interpolationLoc, {
      code: "parse.unterminated-interpolation",
      hint: "Close the interpolation with '}'.",
    });
  }

  const leadingTrim = expr.length - expr.trimStart().length;
  const source = expr.trim();
  const baseLoc = {
    line: loc.line,
    col: loc.col + 1 + start + leadingTrim,
    endLine: loc.line,
    endCol: loc.col + 1 + start + leadingTrim,
  };

  if (source === "") {
    throw new ParseError("empty interpolation", baseLoc, {
      code: "parse.empty-interpolation",
      hint: "Insert a PLX expression between '#{' and '}'.",
    });
  }

  try {
    const tokens = tokenize(source);
    const exprCtx = new ParseContext(tokens);
    const expression = exprCtx.parseExpression();
    exprCtx.skipNewlines();
    exprCtx.expect("EOF");
    remapExpressionLocs(expression, baseLoc);
    return { expression, nextIndex: i };
  } catch (error) {
    throw remapInterpolationError(error, baseLoc);
  }
}

function remapInterpolationError(error: unknown, baseLoc: Loc): ParseError {
  const rawMessage = error instanceof Error ? error.message : String(error);
  const message = stripLocPrefix(rawMessage);

  if (error instanceof ParseError) {
    return new ParseError(message, shiftRelativeLoc(error.loc, baseLoc));
  }

  if (error instanceof LexError) {
    return new ParseError(message, shiftRelativeLoc(tokenLoc(error), baseLoc));
  }

  const loc = extractRelativeLoc(rawMessage);
  return new ParseError(message, loc ? shiftRelativeLoc(loc, baseLoc) : baseLoc);
}

function extractRelativeLoc(message: string): Loc | undefined {
  const match = message.match(/plx:(\d+):(\d+)/);
  if (!match) return undefined;
  return pointLoc(Number(match[1]), Number(match[2]));
}

function shiftRelativeLoc(loc: Loc, baseLoc: Loc): Loc {
  return shiftLoc(loc, baseLoc.line - 1, baseLoc.col);
}

function remapExpressionLocs(expr: Expression, baseLoc: Loc): void {
  expr.loc = shiftRelativeLoc(expr.loc, baseLoc);

  switch (expr.kind) {
    case "binary":
      remapExpressionLocs(expr.left, baseLoc);
      remapExpressionLocs(expr.right, baseLoc);
      return;
    case "unary":
    case "group":
      remapExpressionLocs(expr.expression, baseLoc);
      return;
    case "call":
      for (const arg of expr.args) remapExpressionLocs(arg, baseLoc);
      return;
    case "case_expr":
      remapExpressionLocs(expr.subject, baseLoc);
      for (const arm of expr.arms) {
        remapExpressionLocs(arm.pattern, baseLoc);
        remapExpressionLocs(arm.result, baseLoc);
      }
      if (expr.elseResult) remapExpressionLocs(expr.elseResult, baseLoc);
      return;
    case "array_literal":
      for (const element of expr.elements) remapExpressionLocs(element, baseLoc);
      return;
    case "json_literal":
      for (const entry of expr.entries) remapExpressionLocs(entry.value, baseLoc);
      return;
    case "string_interp":
      for (const part of expr.parts) {
        if (typeof part !== "string") remapExpressionLocs(part, baseLoc);
      }
      return;
    case "identifier":
    case "field_access":
    case "literal":
    case "sql_block":
      return;
  }
}

function binaryOpInfo(tok: Token, next: Token | undefined): BinaryOpInfo | undefined {
  if (tok.type === "IDENT") {
    if (tok.value === "or") return { op: "OR", precedence: 10, assoc: "left" };
    if (tok.value === "and") return { op: "AND", precedence: 20, assoc: "left" };
    return undefined;
  }

  if (tok.type === "ARROW") {
    return isExprStartToken(next) ? { op: "->", precedence: 70, assoc: "left" } : undefined;
  }

  if (tok.type !== "OPERATOR") return undefined;

  switch (tok.value) {
    case "=":
    case "!=":
    case ">":
    case "<":
    case ">=":
    case "<=":
      return { op: tok.value, precedence: 30, assoc: "left" };
    case "||":
      return { op: tok.value, precedence: 40, assoc: "left" };
    case "+":
    case "-":
      return { op: tok.value, precedence: 50, assoc: "left" };
    case "*":
    case "/":
      return { op: tok.value, precedence: 60, assoc: "left" };
    case "->>":
      return { op: tok.value, precedence: 70, assoc: "left" };
    case "::":
      return { op: tok.value, precedence: 80, assoc: "right" };
    default:
      return undefined;
  }
}

// ---------- Standalone helpers ----------

function nullCheck(expr: Expression, loc: Loc): Expression {
  return {
    kind: "binary",
    op: "IS NOT NULL",
    left: expr,
    right: { kind: "literal", value: null, type: "null", loc },
    loc,
  };
}

export function parseSqlBlock(tok: Token): SqlBlockExpr {
  let sql = tok.value;
  let elseRaise: string | undefined;
  let inferredTable: string | undefined;

  const elseMatch = sql.match(ELSE_RAISE_RE);
  if (elseMatch) {
    elseRaise = elseMatch[1];
    sql = sql.slice(0, elseMatch.index ?? 0).trim();
  }

  const tableMatch = sql.match(TABLE_INFER_RE);
  if (tableMatch) {
    inferredTable = tableMatch[1];
  }

  return { kind: "sql_block", sql: sql.trim(), elseRaise, inferredTable, loc: tokenLoc(tok) };
}

function tokenLoc(token: Pick<Token, "file" | "line" | "col" | "endLine" | "endCol">): Loc {
  return {
    file: token.file,
    line: token.line,
    col: token.col,
    endLine: token.endLine,
    endCol: token.endCol,
  };
}
