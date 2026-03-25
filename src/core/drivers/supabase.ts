/**
 * Supabase driver — implements DbClient using postgres npm driver.
 *
 * Sets app.tenant_id on every withClient call.
 * Handles JsonbParam: wraps values with sql.json() (returns Parameter(value, 3802))
 * before passing to sql.unsafe(). postgres.js handleValue() detects Parameter
 * instances in the args array and uses their OID, so jsonb typing works correctly
 * without needing tagged templates.
 */

import type { DbClient, QueryResult } from "../connection.js";
import { JsonbParam } from "../connection.js";
import type { WithClient } from "../container.js";

export interface PostgresWithClientOptions {
  tenantId?: string;
  userId?: string;
  resolveTenantId?: () => string | undefined;
  resolveUserId?: () => string | undefined;
}

/**
 * Create a WithClient using the postgres npm driver.
 *
 * JsonbParam handling:
 *   sql.json(value) returns a postgres.js Parameter(value, 3802).
 *   sql.unsafe(query, args) calls handleValue() on each arg.
 *   handleValue() checks `x instanceof Parameter` and uses x.type as the OID.
 *   So sql.unsafe("SELECT fn($1,$2)", [id, sql.json(props)]) correctly sends
 *   props as jsonb (OID 3802), not json (OID 114).
 */
export function createPostgresWithClient(sql: any, opts?: PostgresWithClientOptions): WithClient {
  const defaultTenantId = opts?.tenantId ?? "dev";
  const defaultUserId = opts?.userId ?? "dev";
  const resolveTenantId = opts?.resolveTenantId;
  const resolveUserId = opts?.resolveUserId;

  return async <T>(cb: (client: DbClient) => Promise<T>): Promise<T> => {
    const tenantId = resolveTenantId?.() ?? defaultTenantId;
    const userId = resolveUserId?.() ?? defaultUserId;
    await sql.unsafe(`SELECT set_config('app.tenant_id', $1, false), set_config('app.user_id', $2, false)`, [
      tenantId,
      userId,
    ]);

    const client: DbClient = {
      async query<R = any>(queryText: string, params?: unknown[]): Promise<QueryResult<R>> {
        if (!params || params.length === 0) {
          return toResult<R>(await sql.unsafe(queryText));
        }

        // Map JsonbParam → sql.json() (Parameter with OID 3802), pass others as-is.
        // sql.unsafe() + handleValue() handles Parameter instances natively.
        const args = params.map((p) =>
          p instanceof JsonbParam ? sql.json(typeof p.value === "string" ? JSON.parse(p.value) : p.value) : p,
        );

        return toResult<R>(await sql.unsafe(queryText, args));
      },
    };

    return cb(client);
  };
}

function toResult<R>(result: any): QueryResult<R> {
  return {
    rows: result as R[],
    rowCount: result.count ?? result.length,
    fields: result.columns?.map((c: any) => ({ name: c.name })),
  };
}
