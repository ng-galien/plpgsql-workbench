import type { DbClient } from "../../connection.js";

export async function notifyPostgrestSchemaReload(client: DbClient): Promise<void> {
  await client.query("NOTIFY pgrst, 'reload schema'").catch(() => {});
}
