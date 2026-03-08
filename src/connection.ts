import { Pool } from "pg";
import type { PoolClient } from "pg";

export type DbClient = PoolClient;

let pool: Pool | null = null;

function getPool(): Pool {
  if (!pool) {
    const connectionString =
      process.env.PLPGSQL_CONNECTION ??
      process.env.DATABASE_URL ??
      "postgresql://postgres@localhost:5432/postgres";
    pool = new Pool({ connectionString, max: 5 });
  }
  return pool;
}

export async function getClient(): Promise<PoolClient> {
  return getPool().connect();
}

export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}
