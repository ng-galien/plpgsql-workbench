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
  | "MODULE"
  | "DEPENDS"
  | "INCLUDE"
  | "EXPORT"
  | "INTERNAL"
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
  file?: string;
  type: TokenType;
  value: string;
  line: number;
  col: number;
  endLine: number;
  endCol: number;
}

export class LexError extends Error {
  code: string;
  file?: string;
  hint?: string;
  endLine: number;
  endCol: number;

  constructor(
    msg: string,
    public line: number,
    public col: number,
    options?: {
      code?: string;
      file?: string;
      hint?: string;
      endLine?: number;
      endCol?: number;
    },
  ) {
    const endLine = options?.endLine ?? line;
    const endCol = options?.endCol ?? col;
    super(`plx:${line}:${col}: ${msg}`);
    this.code = options?.code ?? "lex.invalid-token";
    this.file = options?.file;
    this.hint = options?.hint;
    this.endLine = endLine;
    this.endCol = endCol;
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
  ["module", "MODULE"],
  ["depends", "DEPENDS"],
  ["include", "INCLUDE"],
  ["export", "EXPORT"],
  ["internal", "INTERNAL"],
  ["entity", "ENTITY"],
  ["trait", "TRAIT"],
  ["uses", "USES"],
  ["test", "TEST"],
  ["assert", "ASSERT"],
]);

const SQL_STARTERS = new Set(["select", "insert", "update", "delete", "with"]);
const FOR_IN_RE = /^for\s+(\w+)\s+in\s+(.+)$/i;
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

export function tokenize(source: string, options: { file?: string } = {}): Token[] {
  const lines = source.split("\n");
  const tokens: Token[] = [];
  const indentStack: number[] = [0];
  let lastMeaningful: TokenType | null = null;
  const file = options.file;

  function pushToken(tok: Token): void {
    tokens.push(tok);
    if (tok.type !== "NEWLINE" && tok.type !== "INDENT" && tok.type !== "DEDENT") {
      lastMeaningful = tok.type;
    }
  }

  for (let lineIdx = 0; lineIdx < lines.length; lineIdx++) {
    const rawLine = lines[lineIdx] ?? "";
    const lineNum = lineIdx + 1;
    const trimmed = rawLine.trim();

    if (trimmed === "" || trimmed.startsWith("--")) continue;

    const indent = rawLine.length - trimmed.length;
    const currentIndent = indentStack.at(-1) ?? 0;

    if (indent > currentIndent) {
      indentStack.push(indent);
      pushToken(makeToken(file, "INDENT", "", lineNum, 0));
    } else if (indent < currentIndent) {
      while (indentStack.length > 1 && (indentStack.at(-1) ?? 0) > indent) {
        indentStack.pop();
        pushToken(makeToken(file, "DEDENT", "", lineNum, 0));
      }
      const expectedIndent = indentStack.at(-1) ?? 0;
      if (expectedIndent !== indent) {
        throw new LexError(`inconsistent indentation (got ${indent}, expected ${expectedIndent})`, lineNum, 0, {
          code: "lex.inconsistent-indentation",
          file,
          hint: "Align the block indentation with the previous PLX block level.",
        });
      }
    }

    const lowerTrimmed = trimmed.toLowerCase();

    // Standalone SQL at statement start
    if (
      lastMeaningful !== "ASSIGN" &&
      (lowerTrimmed.startsWith("update ") || lowerTrimmed.startsWith("insert ") || lowerTrimmed.startsWith("delete "))
    ) {
      const sqlBlock = collectSqlLines(lines, lineIdx + 1, trimmed, indent);
      pushToken(makeToken(file, "SQL_BLOCK", sqlBlock.sql, lineNum, indent, sqlBlock.endLine, sqlBlock.endCol));
      lineIdx = Math.max(lineIdx, sqlBlock.lastLine);
      pushToken(makeToken(file, "NEWLINE", "", lineNum, 0));
      continue;
    }

    // for VAR in SQL_QUERY: — preserve raw SQL
    if (lowerTrimmed.startsWith("for ")) {
      const forResult = tokenizeForLine(trimmed, lineNum, indent, lines, lineIdx, file);
      if (forResult) {
        for (const t of forResult.tokens) pushToken(t);
        lineIdx = forResult.lastLine;
        pushToken(makeToken(file, "NEWLINE", "", lineNum, 0));
        continue;
      }
    }

    tokenizeLine(trimmed, lineNum, indent, tokens, lines, lineIdx, pushToken, file);
  }

  while (indentStack.length > 1) {
    indentStack.pop();
    pushToken(makeToken(file, "DEDENT", "", lines.length, 0));
  }

  pushToken(makeToken(file, "EOF", "", lines.length + 1, 0));
  return tokens;
}

function tokenizeForLine(
  trimmed: string,
  lineNum: number,
  baseIndent: number,
  allLines: string[],
  lineIdx: number,
  file?: string,
): { tokens: Token[]; lastLine: number } | null {
  const m = trimmed.match(FOR_IN_RE);
  if (!m) return null;

  const varName = m[1] ?? "";
  let sqlPart = m[2] ?? "";
  let lastLine = lineIdx;
  let endsWithColon = false;

  if (sqlPart.endsWith(":")) {
    sqlPart = sqlPart.slice(0, -1).trim();
    endsWithColon = true;
  }

  if (!endsWithColon) {
    for (let i = lineIdx + 1; i < allLines.length; i++) {
      const raw = allLines[i] ?? "";
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
    makeToken(file, "FOR", "for", lineNum, baseIndent),
    makeToken(file, "IDENT", varName, lineNum, baseIndent + 4),
    makeToken(file, "IN", "in", lineNum, baseIndent + 4 + varName.length + 1),
    makeToken(file, "SQL_BLOCK", sqlPart.trim(), lineNum, baseIndent + 4 + varName.length + 4),
    makeToken(file, "COLON", ":", lineNum, 0),
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
  file?: string,
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
      push(makeToken(file, "OPERATOR", "::", lineNum, col));
      pos += 2;
      continue;
    }

    // := (assignment, possibly followed by SQL)
    if (line[pos] === ":" && line[pos + 1] === "=") {
      push(makeToken(file, "ASSIGN", ":=", lineNum, col));
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
        push(makeToken(file, "SQL_BLOCK", sqlBlock.sql, lineNum, col + 2, sqlBlock.endLine, sqlBlock.endCol));
        for (let i = lineIdx + 1; i <= sqlBlock.lastLine; i++) allLines[i] = "";
        return;
      }
      continue;
    }

    if (line[pos] === "-" && line[pos + 1] === ">" && line[pos + 2] === ">") {
      push(makeToken(file, "OPERATOR", "->>", lineNum, col));
      pos += 3;
      continue;
    }
    if (line[pos] === "-" && line[pos + 1] === ">") {
      push(makeToken(file, "ARROW", "->", lineNum, col));
      pos += 2;
      continue;
    }
    if (line[pos] === "<" && line[pos + 1] === "<") {
      push(makeToken(file, "APPEND", "<<", lineNum, col));
      pos += 2;
      continue;
    }
    if (line[pos] === "|" && line[pos + 1] === ">") {
      push(makeToken(file, "PIPE", "|>", lineNum, col));
      pos += 2;
      continue;
    }
    if (line[pos] === "|" && line[pos + 1] === "|") {
      push(makeToken(file, "OPERATOR", "||", lineNum, col));
      pos += 2;
      continue;
    }
    if (line[pos] === "!" && line[pos + 1] === "=") {
      push(makeToken(file, "OPERATOR", "!=", lineNum, col));
      pos += 2;
      continue;
    }
    if (line[pos] === ">" && line[pos + 1] === "=") {
      push(makeToken(file, "OPERATOR", ">=", lineNum, col));
      pos += 2;
      continue;
    }
    if (line[pos] === "<" && line[pos + 1] === "=") {
      push(makeToken(file, "OPERATOR", "<=", lineNum, col));
      pos += 2;
      continue;
    }

    const ch = line[pos];
    if (ch === undefined) break;
    const singleType = SINGLE_CHARS[ch];
    if (singleType) {
      push(makeToken(file, singleType, ch, lineNum, col));
      pos++;
      continue;
    }

    if (ch === "=" || ch === ">" || ch === "<" || ch === "+" || ch === "-" || ch === "*" || ch === "/") {
      push(makeToken(file, "OPERATOR", ch, lineNum, col));
      pos++;
      continue;
    }

    // String literals
    if (ch === '"' && line[pos + 1] === '"' && line[pos + 2] === '"') {
      const sqlBlock = readTripleQuotedSql(allLines, lineIdx, baseCol, pos, file);
      push(makeToken(file, "SQL_BLOCK", sqlBlock.sql, lineNum, col, sqlBlock.endLine, sqlBlock.endCol));
      for (let i = lineIdx + 1; i <= sqlBlock.lastLine; i++) allLines[i] = "";
      return;
    }

    if (ch === "'" || ch === '"') {
      const { value, end, isInterp } = readString(line, pos, ch, lineNum);
      push(makeToken(file, isInterp ? "INTERP_STRING" : "STRING", value, lineNum, col, lineNum, baseCol + end));
      pos = end;
      continue;
    }

    // Numbers
    if (ch >= "0" && ch <= "9") {
      const start = pos;
      while (pos < line.length) {
        const next = line[pos];
        if (next === undefined || !((next >= "0" && next <= "9") || next === ".")) break;
        pos++;
      }
      push(makeToken(file, "NUMBER", line.slice(start, pos), lineNum, col));
      continue;
    }

    // Identifiers and keywords
    if (isIdentStart(ch)) {
      const start = pos;
      while (pos < line.length) {
        const next = line[pos];
        if (next === undefined || !isIdentChar(next)) break;
        pos++;
      }
      const ident = line.slice(start, pos);
      const kw = KEYWORDS.get(ident.toLowerCase());
      if (kw) {
        push(makeToken(file, kw, ident.toLowerCase(), lineNum, col));
      } else if (ident === "true" || ident === "false") {
        push(makeToken(file, "NUMBER", ident, lineNum, col));
      } else {
        push(makeToken(file, "IDENT", ident, lineNum, col));
      }
      continue;
    }

    throw new LexError(`unexpected character '${ch}'`, lineNum, col, {
      code: "lex.unexpected-character",
      file,
      hint: "Check for a missing quote, comma, or unsupported operator in this expression.",
      endLine: lineNum,
      endCol: col + 1,
    });
  }

  push(makeToken(file, "NEWLINE", "", lineNum, 0));
}

/** Collect SQL continuation lines deeper than baseIndent, including optional else raise */
function collectSqlLines(
  lines: string[],
  startLine: number,
  initialSql: string,
  baseIndent: number,
): { sql: string; lastLine: number; endLine: number; endCol: number } {
  let sql = initialSql;
  let lastLine = startLine - 1;
  let endLine = startLine;
  let endCol = initialSql.length;

  // Track paren depth for subquery blocks like := (SELECT ...)
  let parenDepth = 0;
  for (const ch of initialSql) {
    if (ch === "(") parenDepth++;
    else if (ch === ")") parenDepth--;
  }

  for (let i = startLine; i < lines.length; i++) {
    const raw = lines[i] ?? "";
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
        endLine = i + 1;
        endCol = t.length;
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
    endLine = i + 1;
    endCol = t.length;

    // If parens just balanced, stop after this line unless SQL clearly continues
    if (parenDepth <= 0 && indent <= baseIndent && !isContinuation) break;
  }

  return { sql, lastLine, endLine, endCol };
}

function readTripleQuotedSql(
  allLines: string[],
  lineIdx: number,
  baseIndent: number,
  quotePos: number,
  file?: string,
): { sql: string; lastLine: number; endLine: number; endCol: number } {
  const openingLine = allLines[lineIdx] ?? "";
  const openingContent = openingLine.slice(baseIndent).trimEnd();
  const trailing = openingContent.slice(quotePos + 3).trim();
  const lineNum = lineIdx + 1;

  if (trailing !== "") {
    throw new LexError("triple-quoted SQL opener must terminate the line", lineNum, baseIndent + quotePos + 3, {
      code: "lex.invalid-sql-block-opener",
      file,
      hint: 'Open SQL blocks with """ at the end of the statement line.',
    });
  }

  const contentLines: string[] = [];
  for (let i = lineIdx + 1; i < allLines.length; i++) {
    const raw = allLines[i] ?? "";
    const trimmed = raw.trim();
    const indent = raw.length - raw.trimStart().length;

    if (trimmed === '"""' && indent === baseIndent) {
      return {
        sql: dedentSqlBlock(contentLines),
        lastLine: i,
        endLine: i + 1,
        endCol: indent + 3,
      };
    }

    contentLines.push(raw);
  }

  throw new LexError("unterminated triple-quoted SQL block", lineNum, baseIndent + quotePos, {
    code: "lex.unterminated-sql-block",
    file,
    hint: 'Close the SQL block with """ on its own line at the statement indentation level.',
  });
}

function dedentSqlBlock(lines: string[]): string {
  const trimmedLines = [...lines];
  while (trimmedLines.length > 0 && trimmedLines[0]?.trim() === "") trimmedLines.shift();
  while (trimmedLines.length > 0 && trimmedLines.at(-1)?.trim() === "") trimmedLines.pop();

  let commonIndent = Number.POSITIVE_INFINITY;

  for (const line of trimmedLines) {
    if (line.trim() === "") continue;
    const indent = line.length - line.trimStart().length;
    commonIndent = Math.min(commonIndent, indent);
  }

  if (!Number.isFinite(commonIndent)) {
    return "";
  }

  return trimmedLines
    .map((line) => {
      if (line.trim() === "") return "";
      return line.slice(Math.min(commonIndent, line.length));
    })
    .join("\n");
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
    const ch = line[pos];
    if (ch === undefined) break;
    if (ch === quote) {
      if (quote === "'" && line[pos + 1] === "'") {
        value += "'";
        pos += 2;
        continue;
      }
      break;
    }
    if (quote === '"' && ch === "#" && line[pos + 1] === "{") {
      isInterp = true;
    }
    if (ch === "\\") {
      value += ch + (line[pos + 1] ?? "");
      pos += 2;
    } else {
      value += ch;
      pos++;
    }
  }

  if (pos >= line.length) {
    throw new LexError("unterminated string literal", lineNum, start, {
      code: "lex.unterminated-string",
      hint: "Close the string with a matching quote character.",
      endLine: lineNum,
      endCol: line.length,
    });
  }

  return { value, end: pos + 1, isInterp };
}

function isIdentStart(ch: string): boolean {
  return (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || ch === "_";
}

function isIdentChar(ch: string): boolean {
  return isIdentStart(ch) || (ch >= "0" && ch <= "9");
}

function makeToken(
  file: string | undefined,
  type: TokenType,
  value: string,
  line: number,
  col: number,
  endLine?: number,
  endCol?: number,
): Token {
  const measured = measureSpan(value, line, col);
  return {
    file,
    type,
    value,
    line,
    col,
    endLine: endLine ?? measured.endLine,
    endCol: endCol ?? measured.endCol,
  };
}

function measureSpan(value: string, line: number, col: number): { endLine: number; endCol: number } {
  const parts = value.split("\n");
  if (parts.length === 1) {
    return { endLine: line, endCol: col + value.length };
  }

  return {
    endLine: line + parts.length - 1,
    endCol: parts.at(-1)?.length ?? col,
  };
}
