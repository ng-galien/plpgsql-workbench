import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";
import { GenericContainer, type ImagePullPolicy, type StartedTestContainer } from "testcontainers";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { compile } from "../compiler.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FIXTURES = path.resolve(__dirname, "../../../../fixtures/plx");

describe("PLX entity E2E", () => {
  let container: StartedTestContainer;
  let pool: pg.Pool;
  const expenseContext = {
    permissions: [
      "expense.category.read",
      "expense.category.create",
      "expense.category.modify",
      "expense.category.delete",
    ],
    tenantId: "test",
  } as const;
  const expenseCreateOnlyContext = {
    permissions: ["expense.category.create"],
    tenantId: "test",
  } as const;
  const expenseOtherTenantContext = {
    permissions: [
      "expense.category.read",
      "expense.category.create",
      "expense.category.modify",
      "expense.category.delete",
    ],
    tenantId: "other",
  } as const;
  const purchaseContext = {
    permissions: ["purchase.receipt.read", "purchase.receipt.create", "purchase.receipt.modify"],
    tenantId: "test",
  } as const;

  beforeAll(async () => {
    // Use pg-workbench (local, has pgTAP) if available, fallback to postgres:17
    const image = (await isLocalImage("pg-workbench")) ? "pg-workbench" : "postgres:17";
    const builder = new GenericContainer(image).withExposedPorts(5432).withEnvironment({
      POSTGRES_PASSWORD: "postgres",
      POSTGRES_DB: "postgres",
    });
    if (image === "pg-workbench") {
      builder.withPullPolicy({ shouldPull: () => false } as ImagePullPolicy);
    }
    container = await builder.start();

    pool = new pg.Pool({
      host: container.getHost(),
      max: 1,
      port: container.getMappedPort(5432),
      user: "postgres",
      password: "postgres",
      database: "postgres",
    });

    // Wait for PG to be ready
    let ready = false;
    for (let i = 0; i < 30; i++) {
      try {
        await pool.query("SELECT 1");
        ready = true;
        break;
      } catch {
        await new Promise((r) => setTimeout(r, 500));
      }
    }
    if (!ready) throw new Error("PostgreSQL did not start in time");

    // Create Supabase-like roles referenced by generated RLS policies
    await pool.query("CREATE ROLE anon NOLOGIN");
    await pool.query("CREATE ROLE authenticated NOLOGIN");
  }, 120_000);

  afterAll(async () => {
    await pool?.end();
    await container?.stop();
  });

  it("compiles entity_category.plx, deploys all 6 functions, exercises CRUD", async () => {
    const source = await fs.readFile(path.join(FIXTURES, "entity_category.plx"), "utf-8");
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.functionCount).toBe(6);
    expect(result.ddlSql).toBeDefined();

    await bootstrapSchema(pool);
    await deployCompiledSql(pool, result, 6);

    // CREATE
    const {
      rows: [created],
    } = await queryWithContext<Record<string, unknown>>(
      pool,
      expenseContext,
      `SELECT expense.category_create('{"name":"Test","accounting_code":"601"}'::jsonb) as r`,
    );
    if (!created) throw new Error("expected created row");
    const cr = created.r as Record<string, unknown>;
    expect(cr).toHaveProperty("name", "Test");
    const id = cr.id;
    expect(id).toBeTruthy();

    // READ
    const {
      rows: [readRow],
    } = await queryWithContext<Record<string, unknown>>(
      pool,
      expenseContext,
      `SELECT expense.category_read('${id}') as r`,
    );
    if (!readRow) throw new Error("expected read row");
    const rr = readRow.r as Record<string, unknown>;
    expect(rr).toHaveProperty("name", "Test");
    expect(rr).toHaveProperty("actions");

    await expect(
      queryWithContext(pool, expenseCreateOnlyContext, `SELECT expense.category_read('${id}') as r`),
    ).rejects.toMatchObject({ message: expect.stringContaining("expense.category.read denied") });

    await pool.query("RESET app.tenant_id");
    await pool.query("SELECT set_config('app.permissions', $1, false)", [expenseContext.permissions.join(",")]);
    await expect(pool.query(`SELECT expense.category_read('${id}') as r`)).rejects.toMatchObject({
      message: expect.stringContaining("forbidden: no tenant context"),
    });

    const {
      rows: [otherTenantRead],
    } = await queryWithContext<Record<string, unknown>>(
      pool,
      expenseOtherTenantContext,
      `SELECT expense.category_read('${id}') as r`,
    );
    expect(otherTenantRead?.r).toBeNull();

    // LIST
    const { rows: listRows } = await queryWithContext(pool, expenseContext, "SELECT * FROM expense.category_list()");
    expect(listRows.length).toBeGreaterThanOrEqual(1);

    const { rows: otherTenantRows } = await queryWithContext(
      pool,
      expenseOtherTenantContext,
      "SELECT * FROM expense.category_list()",
    );
    expect(otherTenantRows).toHaveLength(0);

    // UPDATE
    const {
      rows: [updated],
    } = await queryWithContext<Record<string, unknown>>(
      pool,
      expenseContext,
      `SELECT expense.category_update('${id}', '{"name":"Updated"}'::jsonb) as r`,
    );
    if (!updated) throw new Error("expected updated row");
    const ur = updated.r as Record<string, unknown>;
    expect(ur).toHaveProperty("name", "Updated");

    // VALIDATION
    await expect(
      queryWithContext(
        pool,
        expenseContext,
        `SELECT expense.category_create('{"name":"Blocked","accounting_code":"999"}'::jsonb)`,
      ),
    ).rejects.toMatchObject({ detail: "reserved_accounting_code" });

    // DELETE
    const {
      rows: [deleted],
    } = await queryWithContext<Record<string, unknown>>(
      pool,
      expenseContext,
      `SELECT expense.category_delete('${id}') as r`,
    );
    if (!deleted) throw new Error("expected deleted row");
    const dr = deleted.r as Record<string, unknown>;
    expect(dr).toHaveProperty("name", "Updated");
  });

  it("writes emitted entity events to the transactional outbox", async () => {
    const source = `
module purchase

entity purchase.receipt:
  fields:
    supplier_id int
    status text

  event received(receipt_id int, supplier_id int)

  on update(new, old):
    if old.status = 'draft' and new.status = 'received':
      emit received(new.id, new.supplier_id)

fn purchase.record_receipt(receipt_id int, supplier_id int) -> void:
  """
    insert into purchase.receipt_projection (receipt_id, supplier_id)
    values (receipt_id, supplier_id)
  """
  return

on purchase.receipt.received(receipt_id, supplier_id):
  purchase.record_receipt(receipt_id, supplier_id)
`;
    const result = compile(source);

    expect(result.errors).toHaveLength(0);
    expect(result.ddlSql).toContain("purchase._event_outbox");

    await bootstrapSchema(pool);
    await deployDdl(pool, result);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS purchase.receipt_projection (
        receipt_id int PRIMARY KEY,
        supplier_id int NOT NULL
      )
    `);
    await deployFunctions(pool, result, 9);

    const {
      rows: [created],
    } = await queryWithContext<Record<string, unknown>>(
      pool,
      purchaseContext,
      `SELECT purchase.receipt_create('{"supplier_id":42,"status":"draft"}'::jsonb) as r`,
    );
    if (!created) throw new Error("expected created row");
    const receipt = created.r as Record<string, unknown>;
    const id = String(receipt.id);

    await queryWithContext(
      pool,
      purchaseContext,
      `SELECT purchase.receipt_update($1, '{"status":"received"}'::jsonb)`,
      [id],
    );

    const { rows } = await pool.query<{
      aggregate_id: string | null;
      aggregate_type: string;
      correlation_id: string;
      event_name: string;
      metadata: Record<string, unknown>;
      payload: Record<string, unknown>;
    }>(`
      SELECT event_name, aggregate_type, aggregate_id, payload, metadata, correlation_id
      FROM purchase._event_outbox
      ORDER BY id
    `);

    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({
      event_name: "purchase.receipt.received",
      aggregate_type: "purchase.receipt",
      aggregate_id: id,
      payload: { receipt_id: Number(id), supplier_id: 42 },
      metadata: { operation: "update", entity: "purchase.receipt" },
    });
    expect(rows[0]?.correlation_id).toMatch(/^\d+$/);

    const { rows: consumedRows } = await pool.query<{ receipt_id: number; supplier_id: number }>(`
      SELECT receipt_id, supplier_id
      FROM purchase.receipt_projection
    `);
    expect(consumedRows).toEqual([{ receipt_id: Number(id), supplier_id: 42 }]);

    const { rows: deliveries } = await pool.query<{ consumer_key: string }>(`
      SELECT consumer_key
      FROM purchase._event_delivery
    `);
    expect(deliveries).toEqual([{ consumer_key: "purchase.on_purchase_receipt_received_1" }]);
  });

  it("uses p_input consistently in update validation and preserves grouped transition guards", async () => {
    const source = `
module demo

entity demo.project:
  fields:
    name text required
    budget numeric?
    owner text?

  validate:
    budget_positive: coalesce((p_input->>'budget')::numeric, 0) >= 0

  states draft -> active:
    activate(draft -> active):
      guard: coalesce((v_row->>'budget')::numeric, 0) > 0 and v_row->>'owner' is not null
`;
    const result = compile(source);

    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("coalesce((p_input->>'budget')::numeric, 0) >= 0");
    expect(result.sql).toContain(
      "IF NOT (coalesce ( ( v_row ->> 'budget' ) :: numeric , 0 ) > 0 and v_row ->> 'owner' is not null) THEN",
    );

    await bootstrapSchema(pool);
    await deployCompiledSql(pool, result, 7);

    const demoContext = {
      permissions: ["demo.project.read", "demo.project.create", "demo.project.modify", "demo.project.activate"],
      tenantId: "test",
    } as const;

    const {
      rows: [created],
    } = await queryWithContext<Record<string, unknown>>(
      pool,
      demoContext,
      `SELECT demo.project_create('{"name":"Guarded"}'::jsonb) as r`,
    );
    if (!created) throw new Error("expected created project");
    const project = created.r as Record<string, unknown>;
    const id = String(project.id);

    await expect(queryWithContext(pool, demoContext, `SELECT demo.project_activate($1)`, [id])).rejects.toMatchObject({
      message: expect.stringContaining("demo.err_guard_activate"),
    });

    const {
      rows: [updated],
    } = await queryWithContext<Record<string, unknown>>(
      pool,
      demoContext,
      `SELECT demo.project_update($1, '{"budget":5,"owner":"Alice"}'::jsonb) as r`,
      [id],
    );
    expect((updated?.r as Record<string, unknown>)?.budget).toBe(5);

    const {
      rows: [activated],
    } = await queryWithContext<Record<string, unknown>>(pool, demoContext, `SELECT demo.project_activate($1) as r`, [
      id,
    ]);
    expect((activated?.r as Record<string, unknown>)?.status).toBe("active");

    await expect(
      queryWithContext(pool, demoContext, `SELECT demo.project_update($1, '{"budget":-1}'::jsonb) as r`, [id]),
    ).rejects.toMatchObject({ detail: "budget_positive" });
  });
});

async function bootstrapSchema(pool: pg.Pool): Promise<void> {
  await pool.query(
    "DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF; END $$",
  );
}

async function setSessionContext(
  pool: pg.Pool,
  options: { permissions: readonly string[]; tenantId: string },
): Promise<void> {
  await pool.query("SELECT set_config('app.tenant_id', $1, false)", [options.tenantId]);
  await pool.query("SELECT set_config('app.permissions', $1, false)", [options.permissions.join(",")]);
}

async function queryWithContext<T extends pg.QueryResultRow = pg.QueryResultRow>(
  pool: pg.Pool,
  options: { permissions: readonly string[]; tenantId: string },
  text: string,
  values?: unknown[],
): Promise<pg.QueryResult<T>> {
  await setSessionContext(pool, options);
  return values ? pool.query<T>(text, values) : pool.query<T>(text);
}

async function deployCompiledSql(
  pool: pg.Pool,
  result: ReturnType<typeof compile>,
  expectedFunctions: number,
): Promise<void> {
  await deployDdl(pool, result);
  await deployFunctions(pool, result, expectedFunctions);
}

async function deployDdl(pool: pg.Pool, result: ReturnType<typeof compile>): Promise<void> {
  const ddlSql = result.ddlSql;
  expect(ddlSql).toBeDefined();
  if (!ddlSql) throw new Error("expected generated DDL");
  expect(ddlSql).toMatch(/CREATE SCHEMA IF NOT EXISTS ".*"/);
  await pool.query(ddlSql);
}

async function deployFunctions(
  pool: pg.Pool,
  result: ReturnType<typeof compile>,
  expectedFunctions: number,
): Promise<void> {
  const fnBlocks = result.sql.split(/(?=CREATE OR REPLACE FUNCTION)/).filter((s) => s.trim());
  expect(fnBlocks).toHaveLength(expectedFunctions);
  for (const block of fnBlocks) {
    const name = block.match(/FUNCTION\s+(\S+)\(/)?.[1] ?? "unknown";
    try {
      await pool.query(block);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new Error(`Deploy ${name} failed: ${msg}`);
    }
  }
}

async function isLocalImage(name: string): Promise<boolean> {
  try {
    const { execFile } = await import("node:child_process");
    const { promisify } = await import("node:util");
    const exec = promisify(execFile);
    await exec("docker", ["image", "inspect", name]);
    return true;
  } catch {
    return false;
  }
}
