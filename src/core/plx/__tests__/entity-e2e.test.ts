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

    await bootstrapSchema(pool, "expense");
    await deployCompiledSql(pool, result, 6);

    // CREATE
    const {
      rows: [created],
    } = await pool.query<Record<string, unknown>>(
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
    } = await pool.query<Record<string, unknown>>(`SELECT expense.category_read('${id}') as r`);
    if (!readRow) throw new Error("expected read row");
    const rr = readRow.r as Record<string, unknown>;
    expect(rr).toHaveProperty("name", "Test");
    expect(rr).toHaveProperty("actions");

    // LIST
    const { rows: listRows } = await pool.query("SELECT * FROM expense.category_list()");
    expect(listRows.length).toBeGreaterThanOrEqual(1);

    // UPDATE
    const {
      rows: [updated],
    } = await pool.query<Record<string, unknown>>(
      `SELECT expense.category_update('${id}', '{"name":"Updated"}'::jsonb) as r`,
    );
    if (!updated) throw new Error("expected updated row");
    const ur = updated.r as Record<string, unknown>;
    expect(ur).toHaveProperty("name", "Updated");

    // VALIDATION
    await expect(
      pool.query(`SELECT expense.category_create('{"name":"Blocked","accounting_code":"999"}'::jsonb)`),
    ).rejects.toMatchObject({ detail: "reserved_accounting_code" });

    // DELETE
    const {
      rows: [deleted],
    } = await pool.query<Record<string, unknown>>(`SELECT expense.category_delete('${id}') as r`);
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

    await bootstrapSchema(pool, "purchase");
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
    } = await pool.query<Record<string, unknown>>(
      `SELECT purchase.receipt_create('{"supplier_id":42,"status":"draft"}'::jsonb) as r`,
    );
    if (!created) throw new Error("expected created row");
    const receipt = created.r as Record<string, unknown>;
    const id = String(receipt.id);

    await pool.query(`SELECT purchase.receipt_update($1, '{"status":"received"}'::jsonb)`, [id]);

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
});

async function bootstrapSchema(pool: pg.Pool, schema: string): Promise<void> {
  await pool.query(
    "DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF; END $$",
  );
  await pool.query(`CREATE SCHEMA IF NOT EXISTS ${schema}`);
  await pool.query("SELECT set_config('app.tenant_id', 'test', false)");
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
