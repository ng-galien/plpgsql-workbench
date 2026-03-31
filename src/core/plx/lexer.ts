// PLX Lexer — Indentation-aware tokenizer with SQL passthrough

export type TokenType =
  | "FN"
  | "IF"
  | "ELSE"
  | "ELSIF"
  | "FOR"
  | "IN"
  | "RETURN"
  | "RAISE"
  | "MATCH"
  | "WHEN"
  | "SETOF"
  | "NOT"
  | "YIELD"
  | "CASE"
  | "THEN"
  | "END"
  | "IMPORT"
  | "AS"
  | "ENTITY"
  | "TRAIT"
  | "USES"
  | "TEST"
  | "ASSERT"
  | "INDENT"
  | "DEDENT"
  | "NEWLINE"
  | "ASSIGN"
  | "ARROW"
  | "APPEND"
  | "DOT"
  | "COMMA"
  | "COLON"
  | "QUESTION"
  | "LPAREN"
  | "RPAREN"
  | "LBRACKET"
  | "RBRACKET"
  | "LBRACE"
  | "RBRACE"
  | "IDENT"
  | "NUMBER"
  | "STRING"
  | "INTERP_STRING"
  | "SQL_BLOCK"
  | "OPERATOR"
  | "PIPE"
  | "EOF";

export interface Token {
  type: TokenType;
  value: string;
  line: number;
  col: number;
}

export class LexError extends Error {
  constructor(
    msg: string,
    public line: number,
    public col: number,
  ) {
    super(`plx:${line}:${col}: ${msg}`);
  }
}

const KEYWORDS = new Map<string, TokenType>([
  ["fn", "FN"],
  ["if", "IF"],
  ["else", "ELSE"],
  ["elsif", "ELSIF"],
  ["for", "FOR"],
  ["in", "IN"],
  ["return", "RETURN"],
  ["raise", "RAISE"],
  ["match", "MATCH"],
  ["when", "WHEN"],
  ["setof", "SETOF"],
  ["not", "NOT"],
  ["yield", "YIELD"],
  ["case", "CASE"],
  ["then", "THEN"],
  ["end", "END"],
  ["import", "IMPORT"],
  ["as", "AS"],
  ["entity", "ENTITY"],
  ["trait", "TRAIT"],
  ["uses", "USES"],
  ["test", "TEST"],
  ["assert", "ASSERT"],
]);

const SQL_STARTERS = new Set(["select", "insert", "update", "delete", "with"]);
const FOR_IN_RE = /^for\s+(\w+)\s+in\s+(.+)$/i;
const RETURN_QUERY_RE = /^return\s+(query\s+)(select\b|insert\b|update\b|delete\b|with\b)/i;
const SUBQUERY_RE = /^\(\s*select\b/i;
const SQL_CONTINUATION_RE =
  /^(from|where|group\s+by|order\s+by|limit|offset|fetch|having|window|union|intersect|except|join|left\s+join|right\s+join|full\s+join|cross\s+join|inner\s+join|on|returning|set|values)\b/i;
const SINGLE_CHARS: Record<string, TokenType> = {
  "(": "LPAREN",
  ")": "RPAREN",
  "[": "LBRACKET",
  "]": "RBRACKET",
  "{": "LBRACE",
  "}": "RBRACE",
  ",": "COMMA",
  ":": "COLON",
  ".": "DOT",
  "?": "QUESTION",
};

export function tokenize(source: string): Token[] {
  const lines = source.split("\n");
  const tokens: Token[] = [];
  const indentStack: number[] = [0];
  let lastMeaningful: TokenType | null = null;

  function pushToken(tok: Token): void {
    tokens.push(tok);
    if (tok.type !== "NEWLINE" && tok.type !== "INDENT" && tok.type !== "DEDENT") {
      lastMeaningful = tok.type;
    }
  }

  for (let lineIdx = 0; lineIdx < lines.length; lineIdx++) {
    const rawLine = lines[lineIdx]!;
    const lineNum = lineIdx + 1;
    const trimmed = rawLine.trim();

    if (trimmed === "" || trimmed.startsWith("--")) continue;

    const indent = rawLine.length - trimmed.length;
    const currentIndent = indentStack[indentStack.length - 1]!;

    if (indent > currentIndent) {
      indentStack.push(indent);
      pushToken({ type: "INDENT", value: "", line: lineNum, col: 0 });
    } else if (indent < currentIndent) {
      while (indentStack.length > 1 && indentStack[indentStack.length - 1]! > indent) {
        indentStack.pop();
        pushToken({ type: "DEDENT", value: "", line: lineNum, col: 0 });
      }
      if (indentStack[indentStack.length - 1]! !== indent) {
        throw new LexError(
          `inconsistent indentation (got ${indent}, expected ${indentStack[indentStack.length - 1]})`,
          lineNum,
          0,
        );
      }
    }

    const lowerTrimmed = trimmed.toLowerCase();

    // Standalone SQL at statement start
    if (
      lastMeaningful !== "ASSIGN" &&
      (lowerTrimmed.startsWith("update ") || lowerTrimmed.startsWith("insert ") || lowerTrimmed.startsWith("delete "))
    ) {
      const sqlBlock = collectSqlLines(lines, lineIdx + 1, trimmed, indent);
      pushToken({ type: "SQL_BLOCK", value: sqlBlock.sql, line: lineNum, col: indent });
      lineIdx = Math.max(lineIdx, sqlBlock.lastLine);
      pushToken({ type: "NEWLINE", value: "", line: lineNum, col: 0 });
      continue;
    }

    // for VAR in SQL_QUERY: — preserve raw SQL
    if (lowerTrimmed.startsWith("for ")) {
      const forResult = tokenizeForLine(trimmed, lineNum, indent, lines, lineIdx);
      if (forResult) {
        for (const t of forResult.tokens) pushToken(t);
        lineIdx = forResult.lastLine;
        pushToken({ type: "NEWLINE", value: "", line: lineNum, col: 0 });
        continue;
      }
    }

    // return query <SQL> — capture SQL passthrough (return execute uses PLX expressions, handled in parser)
    const returnQueryMatch = lowerTrimmed.match(RETURN_QUERY_RE);
    if (returnQueryMatch) {
      pushToken({ type: "RETURN", value: "return", line: lineNum, col: indent });
      pushToken({ type: "IDENT", value: "query", line: lineNum, col: indent + 7 });
      const sqlStart = returnQueryMatch[0].length - (returnQueryMatch[2]?.length ?? 0);
      const sqlPart = trimmed.slice(sqlStart).trim();
      const sqlBlock = collectSqlLines(lines, lineIdx + 1, sqlPart, indent);
      pushToken({ type: "SQL_BLOCK", value: sqlBlock.sql, line: lineNum, col: indent + sqlStart });
      lineIdx = Math.max(lineIdx, sqlBlock.lastLine);
      pushToken({ type: "NEWLINE", value: "", line: lineNum, col: 0 });
      continue;
    }

    tokenizeLine(trimmed, lineNum, indent, tokens, lines, lineIdx, pushToken);
  }

  while (indentStack.length > 1) {
    indentStack.pop();
    pushToken({ type: "DEDENT", value: "", line: lines.length, col: 0 });
  }

  pushToken({ type: "EOF", value: "", line: lines.length + 1, col: 0 });
  return tokens;
}

function tokenizeForLine(
  trimmed: string,
  lineNum: number,
  baseIndent: number,
  allLines: string[],
  lineIdx: number,
): { tokens: Token[]; lastLine: number } | null {
  const m = trimmed.match(FOR_IN_RE);
  if (!m) return null;

  const varName = m[1]!;
  let sqlPart = m[2]!;
  let lastLine = lineIdx;
  let endsWithColon = false;

  if (sqlPart.endsWith(":")) {
    sqlPart = sqlPart.slice(0, -1).trim();
    endsWithColon = true;
  }

  if (!endsWithColon) {
    for (let i = lineIdx + 1; i < allLines.length; i++) {
      const raw = allLines[i]!;
      const t = raw.trim();
      if (t === "" || t.startsWith("--")) {
        lastLine = i;
        continue;
      }
      const indent = raw.length - t.length;
      if (indent <= baseIndent) break;
      if (t.endsWith(":")) {
        sqlPart += `\n${t.slice(0, -1).trim()}`;
        lastLine = i;
        allLines[i] = "";
        endsWithColon = true;
        break;
      }
      sqlPart += `\n${t}`;
      lastLine = i;
      allLines[i] = "";
    }
  }

  if (!endsWithColon) return null;

  const tokens: Token[] = [
    { type: "FOR", value: "for", line: lineNum, col: baseIndent },
    { type: "IDENT", value: varName, line: lineNum, col: baseIndent + 4 },
    { type: "IN", value: "in", line: lineNum, col: baseIndent + 4 + varName.length + 1 },
    { type: "SQL_BLOCK", value: sqlPart.trim(), line: lineNum, col: baseIndent + 4 + varName.length + 4 },
    { type: "COLON", value: ":", line: lineNum, col: 0 },
  ];

  return { tokens, lastLine };
}

function tokenizeLine(
  line: string,
  lineNum: number,
  baseCol: number,
  _tokens: Token[],
  allLines: string[],
  lineIdx: number,
  push: (tok: Token) => void,
): void {
  let pos = 0;

  while (pos < line.length) {
    if (line[pos] === " " || line[pos] === "\t") {
      pos++;
      continue;
    }
    if (line[pos] === "-" && line[pos + 1] === "-") break;

    const col = baseCol + pos;

    // :: (PG type cast)
    if (line[pos] === ":" && line[pos + 1] === ":") {
      push({ type: "OPERATOR", value: "::", line: lineNum, col });
      pos += 2;
      continue;
    }

    // := (assignment, possibly followed by SQL)
    if (line[pos] === ":" && line[pos + 1] === "=") {
      push({ type: "ASSIGN", value: ":=", line: lineNum, col });
      pos += 2;

      // Check for SQL keyword after :=
      let sqlStart = pos;
      while (sqlStart < line.length && (line[sqlStart] === " " || line[sqlStart] === "\t")) sqlStart++;
      const restStart = sqlStart;
      let wordEnd = sqlStart;
      while (wordEnd < line.length && line[wordEnd] !== " " && line[wordEnd] !== "(" && line[wordEnd] !== "\t")
        wordEnd++;
      const firstWord = line.slice(sqlStart, wordEnd).toLowerCase();

      const isSqlStarter = SQL_STARTERS.has(firstWord);
      const isSubquery = !isSqlStarter && line[restStart] === "(" && SUBQUERY_RE.test(line.slice(restStart));

      if (isSqlStarter || isSubquery) {
        const rest = line.slice(restStart);
        const currentLine = allLines[lineIdx] ?? "";
        const assignIndent = currentLine.length - currentLine.trimStart().length;
        const sqlBlock = collectSqlLines(allLines, lineIdx + 1, rest, assignIndent);
        push({ type: "SQL_BLOCK", value: sqlBlock.sql, line: lineNum, col: col + 2 });
        for (let i = lineIdx + 1; i <= sqlBlock.lastLine; i++) allLines[i] = "";
        return;
      }
      continue;
    }

    if (line[pos] === "-" && line[pos + 1] === ">" && line[pos + 2] === ">") {
      push({ type: "OPERATOR", value: "->>", line: lineNum, col });
      pos += 3;
      continue;
    }
    if (line[pos] === "-" && line[pos + 1] === ">") {
      push({ type: "ARROW", value: "->", line: lineNum, col });
      pos += 2;
      continue;
    }
    if (line[pos] === "<" && line[pos + 1] === "<") {
      push({ type: "APPEND", value: "<<", line: lineNum, col });
      pos += 2;
      continue;
    }
    if (line[pos] === "|" && line[pos + 1] === ">") {
      push({ type: "PIPE", value: "|>", line: lineNum, col });
      pos += 2;
      continue;
    }
    if (line[pos] === "|" && line[pos + 1] === "|") {
      push({ type: "OPERATOR", value: "||", line: lineNum, col });
      pos += 2;
      continue;
    }
    if (line[pos] === "!" && line[pos + 1] === "=") {
      push({ type: "OPERATOR", value: "!=", line: lineNum, col });
      pos += 2;
      continue;
    }
    if (line[pos] === ">" && line[pos + 1] === "=") {
      push({ type: "OPERATOR", value: ">=", line: lineNum, col });
      pos += 2;
      continue;
    }
    if (line[pos] === "<" && line[pos + 1] === "=") {
      push({ type: "OPERATOR", value: "<=", line: lineNum, col });
      pos += 2;
      continue;
    }

    const ch = line[pos]!;
    const singleType = SINGLE_CHARS[ch];
    if (singleType) {
      push({ type: singleType, value: ch, line: lineNum, col });
      pos++;
      continue;
    }

    if (ch === "=" || ch === ">" || ch === "<" || ch === "+" || ch === "-" || ch === "*" || ch === "/") {
      push({ type: "OPERATOR", value: ch, line: lineNum, col });
      pos++;
      continue;
    }

    // String literals
    if (ch === "'" || ch === '"') {
      const { value, end, isInterp } = readString(line, pos, ch, lineNum);
      push({ type: isInterp ? "INTERP_STRING" : "STRING", value, line: lineNum, col });
      pos = end;
      continue;
    }

    // Numbers
    if (ch >= "0" && ch <= "9") {
      const start = pos;
      while (pos < line.length && ((line[pos]! >= "0" && line[pos]! <= "9") || line[pos] === ".")) pos++;
      push({ type: "NUMBER", value: line.slice(start, pos), line: lineNum, col });
      continue;
    }

    // Identifiers and keywords
    if (isIdentStart(ch)) {
      const start = pos;
      while (pos < line.length && isIdentChar(line[pos]!)) pos++;
      const ident = line.slice(start, pos);
      const kw = KEYWORDS.get(ident.toLowerCase());
      if (kw) {
        push({ type: kw, value: ident.toLowerCase(), line: lineNum, col });
      } else if (ident === "true" || ident === "false") {
        push({ type: "NUMBER", value: ident, line: lineNum, col });
      } else {
        push({ type: "IDENT", value: ident, line: lineNum, col });
      }
      continue;
    }

    throw new LexError(`unexpected character '${ch}'`, lineNum, col);
  }

  push({ type: "NEWLINE", value: "", line: lineNum, col: 0 });
}

/** Collect SQL continuation lines deeper than baseIndent, including optional else raise */
function collectSqlLines(
  lines: string[],
  startLine: number,
  initialSql: string,
  baseIndent: number,
): { sql: string; lastLine: number } {
  let sql = initialSql;
  let lastLine = startLine - 1;

  // Track paren depth for subquery blocks like := (SELECT ...)
  let parenDepth = 0;
  for (const ch of initialSql) {
    if (ch === "(") parenDepth++;
    else if (ch === ")") parenDepth--;
  }

  for (let i = startLine; i < lines.length; i++) {
    const raw = lines[i]!;
    const t = raw.trim();
    if (t === "" || t.startsWith("--")) {
      lastLine = i;
      continue;
    }

    const indent = raw.length - t.length;

    const isContinuation = SQL_CONTINUATION_RE.test(t);

    // If parens are balanced AND indent dropped, stop unless SQL clearly continues
    if (parenDepth <= 0 && indent <= baseIndent) {
      if (t.toLowerCase().startsWith("else raise")) {
        sql += `\n${t}`;
        lastLine = i;
      } else if (!isContinuation) {
        break;
      }
    }

    // Track parens in this line (outside strings)
    for (const ch of t) {
      if (ch === "(") parenDepth++;
      else if (ch === ")") parenDepth--;
    }

    sql += `\n${t}`;
    lastLine = i;

    // If parens just balanced, stop after this line unless SQL clearly continues
    if (parenDepth <= 0 && indent <= baseIndent && !isContinuation) break;
  }

  return { sql, lastLine };
}

function readString(
  line: string,
  start: number,
  quote: string,
  lineNum: number,
): { value: string; end: number; isInterp: boolean } {
  let pos = start + 1;
  let value = "";
  let isInterp = false;

  while (pos < line.length) {
    if (line[pos] === quote) {
      if (quote === "'" && line[pos + 1] === "'") {
        value += "'";
        pos += 2;
        continue;
      }
      break;
    }
    if (quote === '"' && line[pos] === "#" && line[pos + 1] === "{") {
      isInterp = true;
    }
    if (line[pos] === "\\") {
      value += line[pos]! + (line[pos + 1] ?? "");
      pos += 2;
    } else {
      value += line[pos];
      pos++;
    }
  }

  if (pos >= line.length) {
    throw new LexError("unterminated string literal", lineNum, start);
  }

  return { value, end: pos + 1, isInterp };
}

function isIdentStart(ch: string): boolean {
  return (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || ch === "_";
}

function isIdentChar(ch: string): boolean {
  return isIdentStart(ch) || (ch >= "0" && ch <= "9");
}
