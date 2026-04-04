import type { DbClient } from "../../connection.js";

export interface TransactionOptions {
  beginSql?: string;
}

function toSavepointName(name: string): string {
  const normalized = name.replace(/[^a-zA-Z0-9_]/g, "_");
  if (normalized.length === 0) return "sp";
  if (/^[0-9]/.test(normalized)) return `sp_${normalized}`;
  return normalized;
}

export async function withTransaction<T>(
  client: DbClient,
  work: () => Promise<T>,
  options: TransactionOptions = {},
): Promise<T> {
  await client.query(options.beginSql ?? "BEGIN");
  try {
    const result = await work();
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK").catch(() => {});
    throw error;
  }
}

export async function withSavepoint<T>(client: DbClient, name: string, work: () => Promise<T>): Promise<T> {
  const savepoint = toSavepointName(name);
  await client.query(`SAVEPOINT ${savepoint}`);
  try {
    const result = await work();
    await client.query(`RELEASE SAVEPOINT ${savepoint}`);
    return result;
  } catch (error) {
    await client.query(`ROLLBACK TO SAVEPOINT ${savepoint}`).catch(() => {});
    throw error;
  }
}
