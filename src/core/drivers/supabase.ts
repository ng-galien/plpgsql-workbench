/**
 * Supabase driver — implements DbClient using @supabase/supabase-js.
 *
 * Uses supabase.rpc('exec_sql', { sql, params }) for raw SQL execution.
 * Requires a PostgreSQL function `exec_sql(sql text, params jsonb)` deployed
 * in the database (see below).
 *
 * For Supabase Edge Functions: uses the auto-injected SUPABASE_DB_URL with
 * the postgres npm driver for direct SQL access (no PostgREST overhead).
 */

import type { DbClient, QueryResult } from "../connection.js";
import type { WithClient } from "../container.js";

/**
 * Create a WithClient using the postgres npm driver (direct connection).
 * This is the recommended approach for Edge Functions that need raw SQL.
 *
 * Usage:
 *   import postgres from "postgres";
 *   const sql = postgres(Deno.env.get("SUPABASE_DB_URL")!);
 *   const withClient = createPostgresWithClient(sql);
 */
export function createPostgresWithClient(sql: any): WithClient {
  const client: DbClient = {
    async query<T = any>(text: string, params?: unknown[]): Promise<QueryResult<T>> {
      // postgres.js uses tagged template literals, but we need parameterized queries.
      // Use the unsafe() method for dynamic SQL with parameters.
      if (params && params.length > 0) {
        // Replace $1, $2, ... with postgres.js positional syntax
        const result = await sql.unsafe(text, params);
        return {
          rows: result as T[],
          rowCount: result.count ?? result.length,
          fields: result.columns?.map((c: any) => ({ name: c.name })),
        };
      }
      const result = await sql.unsafe(text);
      return {
        rows: result as T[],
        rowCount: result.count ?? result.length,
        fields: result.columns?.map((c: any) => ({ name: c.name })),
      };
    },
  };

  return async <T>(cb: (client: DbClient) => Promise<T>): Promise<T> => {
    return cb(client);
  };
}
