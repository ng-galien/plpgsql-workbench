import { getClient, type DbClient } from "./connection.js";

export type ToolResult = { content: { type: "text"; text: string }[] };

export function text(t: string): ToolResult {
  return { content: [{ type: "text", text: t }] };
}

export function wrap(uri: string, completeness: "full" | "partial", body: string, next: string[]): string {
  const parts = [`uri: ${uri}`, `completeness: ${completeness}`, "", body];
  if (next.length > 0) {
    parts.push("", "next:");
    for (const n of next) parts.push(`  - ${n}`);
  }
  return parts.join("\n");
}

export async function withClient<T>(fn: (client: DbClient) => Promise<T>): Promise<T> {
  const client = await getClient();
  try {
    return await fn(client);
  } finally {
    client.release();
  }
}

interface PgError {
  message: string;
  position?: string;
  where?: string;
  hint?: string;
}

export function formatErrorTriplet(err: unknown, sql?: string, fallbackWhere?: string): string {
  const e = err as PgError;
  const problem = e.message ?? String(err);

  let where: string;
  if (e.position && sql) {
    const pos = parseInt(e.position, 10);
    const prefix = sql.slice(0, pos);
    const line = prefix.split("\n").length;
    const col = pos - prefix.lastIndexOf("\n");
    where = `line ${line}, col ${col}`;
  } else if (e.where) {
    where = e.where;
  } else {
    where = fallbackWhere ?? "unknown";
  }

  const fixHint = e.hint ?? null;
  const parts = [`problem: ${problem}`, `where: ${where}`];
  if (fixHint) parts.push(`fix_hint: ${fixHint}`);
  return parts.join("\n");
}
