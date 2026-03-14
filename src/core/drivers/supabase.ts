/**
 * Supabase driver — implements DbClient using postgres npm driver.
 *
 * Sets app.tenant_id on every withClient call:
 * - Dev: 'dev' (default)
 * - Prod: extracted from JWT auth.uid() or passed explicitly
 *
 * For Supabase Edge Functions: uses the auto-injected SUPABASE_DB_URL.
 */

import type { DbClient, QueryResult } from "../connection.js";
import type { WithClient } from "../container.js";

export interface PostgresWithClientOptions {
  /** Default tenant_id to set on each connection. Default: 'dev' */
  tenantId?: string;
  /** Function to resolve tenant_id dynamically (e.g. from JWT). Overrides tenantId. */
  resolveTenantId?: () => string | undefined;
}

/**
 * Create a WithClient using the postgres npm driver (direct connection).
 * Sets app.tenant_id before each callback execution.
 */
export function createPostgresWithClient(sql: any, opts?: PostgresWithClientOptions): WithClient {
  const defaultTenantId = opts?.tenantId ?? "dev";
  const resolveTenantId = opts?.resolveTenantId;

  return async <T>(cb: (client: DbClient) => Promise<T>): Promise<T> => {
    // Resolve tenant_id: dynamic resolver > static default
    const tenantId = resolveTenantId?.() ?? defaultTenantId;

    // Set tenant_id for this session
    await sql.unsafe(`SELECT set_config('app.tenant_id', $1, false)`, [tenantId]);

    const client: DbClient = {
      async query<R = any>(text: string, params?: unknown[]): Promise<QueryResult<R>> {
        if (params && params.length > 0) {
          // postgres.js auto-detects JSON strings and sends them as PG type json (OID 114),
          // but json doesn't support the - operator (only jsonb does).
          // Workaround: wrap JSON strings in a helper object that postgres.js sends as text.
          const safeParams = params.map(p => {
            if (typeof p === "object" && p !== null && !Array.isArray(p)) {
              return JSON.stringify(p);
            }
            return p;
          });
          // Force all params as text type to avoid json/jsonb type confusion
          const types = safeParams.map(() => 0); // 0 = let PG infer from ::cast
          const result = await sql.unsafe(text, safeParams, { types });
          return {
            rows: result as R[],
            rowCount: result.count ?? result.length,
            fields: result.columns?.map((c: any) => ({ name: c.name })),
          };
        }
        const result = await sql.unsafe(text);
        return {
          rows: result as R[],
          rowCount: result.count ?? result.length,
          fields: result.columns?.map((c: any) => ({ name: c.name })),
        };
      },
    };

    return cb(client);
  };
}
