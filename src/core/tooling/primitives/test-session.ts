import type { DbClient } from "../../connection.js";

export interface TestSessionConfig {
  testSchema: string;
  sourceSchema?: string;
  extraSchemas?: string[];
  tenantId?: string;
}

export interface TestSessionState {
  inTransaction: boolean;
  savepoint: string;
  sourceSchema: string;
  permissions: string[];
}

export async function detectOpenTransaction(client: DbClient): Promise<boolean> {
  const { rows } = await client.query<{ in_tx: boolean }>(`SELECT now() != statement_timestamp() AS in_tx`);
  return rows[0]?.in_tx ?? false;
}

export async function inferCrudStylePermissions(client: DbClient, sourceSchema: string): Promise<string[]> {
  const { rows } = await client.query<{ proname: string }>(
    `SELECT p.proname
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = $1
      ORDER BY p.proname`,
    [sourceSchema],
  );

  const permissions = new Set<string>();
  for (const row of rows) {
    const name = row.proname;
    if (name.startsWith("_") || name.startsWith("on_")) continue;
    const match = name.match(/^([a-z0-9_]+)_(create|read|list|view|update|delete|[a-z0-9_]+)$/);
    if (!match) continue;
    const entity = match[1];
    const action = match[2];
    if (!entity || !action) continue;
    const normalized = action === "update" ? "modify" : action === "list" || action === "view" ? "read" : action;
    permissions.add(`${sourceSchema}.${entity}.${normalized}`);
  }

  return [...permissions].sort();
}

export async function openDeterministicTestSession(
  client: DbClient,
  config: TestSessionConfig,
): Promise<TestSessionState> {
  const sourceSchema = config.sourceSchema ?? deriveSourceSchema(config.testSchema);
  const inTransaction = await detectOpenTransaction(client);
  const savepoint = "test_run";

  if (inTransaction) {
    await client.query(`SAVEPOINT ${savepoint}`);
  } else {
    await client.query("BEGIN");
  }

  const searchPath = [config.testSchema, sourceSchema, ...(config.extraSchemas ?? []), "public"];
  await client.query(`SET LOCAL search_path TO ${searchPath.map(quoteIdent).join(", ")}`);
  await client.query(`SET LOCAL app.tenant_id = ${quoteLiteral(config.tenantId ?? "test")}`);
  const permissions = await inferCrudStylePermissions(client, sourceSchema);
  if (permissions.length > 0) {
    await client.query(`SET LOCAL app.permissions = ${quoteLiteral(permissions.join(","))}`);
  }

  return {
    inTransaction,
    savepoint,
    sourceSchema,
    permissions,
  };
}

export async function closeDeterministicTestSession(client: DbClient, state: TestSessionState): Promise<void> {
  if (state.inTransaction) {
    await client.query(`RELEASE SAVEPOINT ${state.savepoint}`);
  } else {
    await client.query("ROLLBACK");
  }
}

export async function rollbackDeterministicTestSession(client: DbClient, state: TestSessionState): Promise<void> {
  if (state.inTransaction) {
    await client.query(`ROLLBACK TO SAVEPOINT ${state.savepoint}`).catch(() => {});
  } else {
    await client.query("ROLLBACK").catch(() => {});
  }
}

function deriveSourceSchema(testSchema: string): string {
  return testSchema.replace(/_(ut|it)$/, "");
}

function quoteIdent(value: string): string {
  return `"${value.replace(/"/g, '""')}"`;
}

function quoteLiteral(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}
