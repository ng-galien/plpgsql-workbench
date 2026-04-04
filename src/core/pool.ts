/**
 * pool.ts — PostgreSQL pool infrastructure.
 *
 * Shared across plugins — not tied to any specific pack.
 */

import type { Pool } from "pg";
import type { DbClient } from "./connection.js";
import type { WithClient } from "./container.js";

type PoolLogger = Pick<Console, "error">;
type PgPoolLike = Pick<Pool, "connect" | "on">;
type PgPoolClientLike = DbClient & {
  release: (destroy?: boolean) => void;
  on: (event: "error", listener: (error: Error) => void) => void;
  removeListener?: (event: "error", listener: (error: Error) => void) => void;
};

export function attachPoolErrorHandler(pool: Pool, logger: PoolLogger = console): Pool {
  pool.on("error", (error: Error) => {
    logger.error("[plpgsql] Unexpected idle PostgreSQL client error", error);
  });
  return pool;
}

export function createWithClient(pool: PgPoolLike, logger: PoolLogger = console, tenantId = "dev"): WithClient {
  const fn: WithClient = async <T>(cb: (client: DbClient) => Promise<T>): Promise<T> => {
    const client = (await pool.connect()) as PgPoolClientLike;
    let broken = false;
    const onClientError = (error: Error) => {
      broken = true;
      logger.error("[plpgsql] PostgreSQL client error during tool execution", error);
    };

    client.on("error", onClientError);
    try {
      await client.query("SELECT set_config('app.tenant_id', $1, false)", [tenantId]);
      return await cb(client);
    } finally {
      client.removeListener?.("error", onClientError);
      await client.query("ROLLBACK").catch(() => {});
      client.release(broken);
    }
  };
  return fn;
}
