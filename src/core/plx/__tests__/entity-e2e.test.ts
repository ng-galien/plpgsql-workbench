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

    // Bootstrap roles + schema
    await pool.query(
      "DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF; END $$",
    );
    await pool.query("CREATE SCHEMA IF NOT EXISTS expense");
    const ddlSql = result.ddlSql;
    expect(ddlSql).toBeDefined();
    if (!ddlSql) throw new Error("expected generated DDL");
    await pool.query(ddlSql);

    // Deploy all functions — every single one must succeed
    const fnBlocks = result.sql.split(/(?=CREATE OR REPLACE FUNCTION)/).filter((s) => s.trim());
    expect(fnBlocks).toHaveLength(6);
    for (const block of fnBlocks) {
      const name = block.match(/FUNCTION\s+(\S+)\(/)?.[1] ?? "unknown";
      try {
        await pool.query(block);
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        throw new Error(`Deploy ${name} failed: ${msg}`);
      }
    }

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
    ).rejects.toMatchObject({ detail: "expense.err_reserved_accounting_code" });

    // DELETE
    const {
      rows: [deleted],
    } = await pool.query<Record<string, unknown>>(`SELECT expense.category_delete('${id}') as r`);
    if (!deleted) throw new Error("expected deleted row");
    const dr = deleted.r as Record<string, unknown>;
    expect(dr).toHaveProperty("name", "Updated");
  });
});

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
