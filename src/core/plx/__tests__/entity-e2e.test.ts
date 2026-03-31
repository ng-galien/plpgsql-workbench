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
    await pool.query(result.ddlSql!);

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

    // CREATE — insert directly to get ID, then use the generated functions
    const {
      rows: [inserted],
    } = await pool.query("INSERT INTO expense.category (name, accounting_code) VALUES ('Test', '601') RETURNING *");
    expect(inserted).toHaveProperty("name", "Test");
    const id = inserted!.id;

    // READ
    const {
      rows: [readRow],
    } = await pool.query<Record<string, unknown>>(`SELECT expense.category_read('${id}') as r`);
    const rr = readRow!.r as Record<string, unknown>;
    expect(rr).toHaveProperty("name", "Test");
    expect(rr).toHaveProperty("actions");

    // LIST
    const { rows: listRows } = await pool.query("SELECT * FROM expense.category_list()");
    expect(listRows.length).toBeGreaterThanOrEqual(1);

    // DELETE
    const {
      rows: [deleted],
    } = await pool.query<Record<string, unknown>>(`SELECT expense.category_delete('${id}') as r`);
    const dr = deleted!.r as Record<string, unknown>;
    expect(dr).toHaveProperty("name", "Test");
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
