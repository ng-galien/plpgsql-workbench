/**
 * Database client interface — abstraction over pg.PoolClient / postgres.js / supabase-js.
 *
 * All tools use `withClient(async (client) => { ... })` where client
 * implements this interface. The actual driver is injected by each pack.
 *
 * Node (dev): pg.PoolClient (full features: transactions, notices, events)
 * Cloudflare/Deno (prod): postgres.js wrapper
 */

/** Query result — default generic kept as Record for compatibility with existing tool code. */
export interface QueryResult<T = Record<string, unknown>> {
  rows: T[];
  rowCount: number | null;
  fields?: { name: string }[];
}

/**
 * Marker for JSONB parameters.
 * Wrap a value with `jsonb()` before passing it to `client.query()`.
 * The driver will serialize it correctly for the underlying PG driver.
 *
 * Usage in tools:
 *   import { jsonb } from "../connection.js";
 *   client.query("SELECT fn($1, $2)", [canvasId, jsonb(props)]);
 */
export class JsonbParam {
  constructor(public readonly value: unknown) {}
}

/** Wrap a value as a JSONB parameter for query(). */
export function jsonb(value: unknown): JsonbParam {
  return new JsonbParam(value);
}

/** Database client — the only thing tools see. */
export interface DbClient {
  query<T = any>(sql: string, params?: unknown[]): Promise<QueryResult<T>>;
  /** PG-specific: listen for notices (used by coverage, dev only). */
  on?(event: string, fn: (...args: any[]) => void): void;
  removeListener?(event: string, fn: (...args: any[]) => void): void;
}
