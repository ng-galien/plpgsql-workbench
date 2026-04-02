import type { TokenType } from "./lexer.js";
import type { ParseContext } from "./parse-context.js";

export function parseCommaSeparated<T>(ctx: ParseContext, endToken: TokenType, parseItem: () => T): T[] {
  const items: T[] = [];
  if (ctx.isAt(endToken)) return items;
  items.push(parseItem());
  while (ctx.isAt("COMMA")) {
    ctx.advance();
    items.push(parseItem());
  }
  return items;
}
