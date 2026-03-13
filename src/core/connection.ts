/**
 * Database client interface — abstraction over pg.PoolClient / supabase-js / etc.
 *
 * All tools use `withClient(async (client) => { ... })` where client
 * implements this interface. The actual driver is injected by each pack.
 *
 * Node (dev): pg.PoolClient (full features: transactions, notices, events)
 * Deno (Edge): supabase-js wrapper (query only, RLS-aware)
 */

/** Query result — kept loose (any) to stay compatible with existing tool code. */
export interface QueryResult<T = any> {
  rows: T[];
  rowCount: number | null;
  fields?: { name: string }[];
}

/** Database client — the only thing tools see. */
export interface DbClient {
  query<T = any>(sql: string, params?: unknown[]): Promise<QueryResult<T>>;
  /** PG-specific: listen for notices (used by coverage, dev only). */
  on?(event: string, fn: (...args: any[]) => void): void;
  removeListener?(event: string, fn: (...args: any[]) => void): void;
}
