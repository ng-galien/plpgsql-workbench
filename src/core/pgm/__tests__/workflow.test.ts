import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import type { DbClient } from "../../connection.js";
import { buildPlxModule } from "../plx-builder.js";
import {
  diffModuleArtifacts,
  prepareModuleWorkflow,
  runModuleI18nSeed,
  sortApplyArtifacts,
  syncModuleBuildFiles,
} from "../workflow.js";

const tmpRoots: string[] = [];

async function createWorkspace(): Promise<string> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "pgm-workflow-"));
  tmpRoots.push(root);
  await fs.mkdir(path.join(root, "modules"), { recursive: true });
  return root;
}

async function writeModule(root: string, name: string): Promise<void> {
  const moduleDir = path.join(root, "modules", name);
  await fs.mkdir(path.join(moduleDir, "src"), { recursive: true });
  await fs.writeFile(
    path.join(moduleDir, "module.json"),
    `${JSON.stringify(
      {
        name,
        version: "0.1.0",
        description: "Quote",
        schemas: { public: name, private: null },
        dependencies: [],
        extensions: [],
        sql: [`build/${name}.ddl.sql`, `build/${name}.func.sql`, `build/${name}_ut.func.sql`],
        assets: {},
        grants: {},
        plx: { entry: `src/${name}.plx` },
      },
      null,
      2,
    )}\n`,
    "utf-8",
  );
  await fs.writeFile(
    path.join(moduleDir, "src", `${name}.plx`),
    `
module ${name}

include "./brand.plx"

export ${name}.brand
`,
    "utf-8",
  );
  await fs.writeFile(
    path.join(moduleDir, "src", "brand.plx"),
    `
fn ${name}.brand() -> text [stable]:
  return "brand"

test "brand":
  assert ${name}.brand() = 'brand'
`,
    "utf-8",
  );
}

async function writeDependencyModule(root: string, name: string, source: string): Promise<void> {
  const moduleDir = path.join(root, "modules", name);
  await fs.mkdir(path.join(moduleDir, "src"), { recursive: true });
  await fs.writeFile(
    path.join(moduleDir, "module.json"),
    `${JSON.stringify(
      {
        name,
        version: "0.1.0",
        description: "Dependency demo",
        schemas: { public: name, private: null },
        dependencies: [],
        extensions: ["pgcrypto"],
        sql: [`build/${name}.ddl.sql`, `build/${name}.func.sql`, `build/${name}_ut.func.sql`],
        assets: {},
        grants: { anon: [name] },
        plx: { entry: `src/${name}.plx` },
      },
      null,
      2,
    )}\n`,
    "utf-8",
  );
  await fs.writeFile(path.join(moduleDir, "src", `${name}.plx`), `${source.trim()}\n`, "utf-8");
}

afterEach(async () => {
  await Promise.all(tmpRoots.splice(0).map((root) => fs.rm(root, { recursive: true, force: true })));
});

describe("pgm module workflow", () => {
  it("prepares module workflow and detects stale build files", async () => {
    const root = await createWorkspace();
    await writeModule(root, "quote");

    const workflow = await prepareModuleWorkflow(root, "quote");

    expect(workflow.prepared.files.map((file: string) => path.basename(file))).toEqual(["quote.plx", "brand.plx"]);
    expect(workflow.artifacts.map((artifact) => artifact.key).sort()).toEqual([
      "ddl:schema:quote",

      "ddl:schema:quote_ut",
      "function:quote.brand",
      "test:quote_ut.test_brand",
    ]);
    expect(workflow.buildFiles).toEqual([
      {
        kind: "ddl",
        file: "build/quote.ddl.sql",
        expectedHash: expect.any(String),
        status: "missing",
      },
      {
        kind: "func",
        file: "build/quote.func.sql",
        expectedHash: expect.any(String),
        status: "missing",
      },
      {
        kind: "test",
        file: "build/quote_ut.func.sql",
        expectedHash: expect.any(String),
        status: "missing",
      },
    ]);
  });

  it("marks build files up to date after build and diffs applied artifacts", async () => {
    const root = await createWorkspace();
    await writeModule(root, "quote");

    const modulesDir = path.join(root, "modules");
    await buildPlxModule(modulesDir, {
      name: "quote",
      version: "0.1.0",
      description: "Quote",
      plx: { entry: "src/quote.plx" },
    });

    const workflow = await prepareModuleWorkflow(root, "quote");
    expect(workflow.buildFiles.map((file) => file.status)).toEqual(["up_to_date", "up_to_date", "up_to_date"]);
    const brandArtifact = workflow.artifacts.find((artifact) => artifact.key === "function:quote.brand");
    expect(brandArtifact).toBeDefined();
    if (!brandArtifact) {
      throw new Error("Expected function:quote.brand artifact");
    }

    const applied = new Map([
      [
        "function:quote.brand",
        {
          key: "function:quote.brand",
          kind: "function" as const,
          name: "quote.brand",
          hash: brandArtifact.hash,
          appliedAt: "2026-03-31 10:00:00+00",
        },
      ],
      [
        "function:quote.old_brand",
        {
          key: "function:quote.old_brand",
          kind: "function" as const,
          name: "quote.old_brand",
          hash: "deadbeefdeadbeef",
          appliedAt: "2026-03-31 09:00:00+00",
        },
      ],
    ]);

    const diff = diffModuleArtifacts(workflow.artifacts, applied);
    expect(diff.changed.map((artifact) => artifact.key).sort()).toEqual([
      "ddl:schema:quote",

      "ddl:schema:quote_ut",
      "test:quote_ut.test_brand",
    ]);
    expect(diff.unchanged.map((artifact) => artifact.key)).toEqual(["function:quote.brand"]);
    expect(diff.obsolete.map((artifact) => artifact.key)).toEqual(["function:quote.old_brand"]);
  });

  it("syncs generated build files to disk before apply", async () => {
    const root = await createWorkspace();
    await writeModule(root, "quote");

    const workflow = await prepareModuleWorkflow(root, "quote");
    expect(workflow.buildFiles.map((file) => file.status)).toEqual(["missing", "missing", "missing"]);

    const written = await syncModuleBuildFiles(workflow);
    expect(written).toEqual(["build/quote.ddl.sql", "build/quote.func.sql", "build/quote_ut.func.sql"]);

    expect(workflow.buildFiles.map((file) => file.status)).toEqual(["up_to_date", "up_to_date", "up_to_date"]);
    await expect(
      fs.readFile(path.join(root, "modules", "quote", "build", "quote.ddl.sql"), "utf-8"),
    ).resolves.toContain('CREATE SCHEMA IF NOT EXISTS "quote"');
    await expect(
      fs.readFile(path.join(root, "modules", "quote", "build", "quote.func.sql"), "utf-8"),
    ).resolves.toContain("quote.brand");
    await expect(
      fs.readFile(path.join(root, "modules", "quote", "build", "quote_ut.func.sql"), "utf-8"),
    ).resolves.toContain("quote_ut.test_brand");
  });

  it("orders apply artifacts by dependency graph instead of plain kind rank", async () => {
    const root = await createWorkspace();
    await writeDependencyModule(
      root,
      "quote",
      `
module quote

fn quote.lines() -> int [stable]:
  return 1

fn quote.total() -> int [stable]:
  return quote.lines()

test "total":
  assert quote.total() = 1
`,
    );

    const workflow = await prepareModuleWorkflow(root, "quote");
    const ordered = sortApplyArtifacts(workflow.artifacts);

    const keys = ordered.map((artifact) => artifact.key);
    expect(keys[0]).toBe("extensions");
    const ddlKeys = keys.filter((k) => k.startsWith("ddl:")).sort();
    expect(ddlKeys).toEqual(["ddl:schema:quote", "ddl:schema:quote_ut"]);
    const nonDdlKeys = keys.filter((k) => !k.startsWith("ddl:") && k !== "extensions");
    expect(nonDdlKeys).toEqual(["function:quote.lines", "function:quote.total", "test:quote_ut.test_total", "grants"]);
  });

  it("orders split ddl artifacts so referenced tables exist before foreign keys", async () => {
    const root = await createWorkspace();
    await writeDependencyModule(
      root,
      "quote",
      `
module quote

entity quote.note:
  fields:
    title text required

entity quote.task:
  fields:
    note_id int? ref(quote.note)

  payload:
    title text required
`,
    );

    const workflow = await prepareModuleWorkflow(root, "quote");
    const ordered = sortApplyArtifacts(workflow.artifacts);
    const keys = ordered.map((artifact) => artifact.key);

    expect(keys).toContain("ddl:schema:quote");
    expect(keys).toContain("ddl:table:quote.note");
    expect(keys).toContain("ddl:table:quote.task");
    expect(keys).toContain("ddl:fk:quote.task.note_id");
    expect(keys.indexOf("ddl:schema:quote")).toBeLessThan(keys.indexOf("ddl:table:quote.note"));
    expect(keys.indexOf("ddl:schema:quote")).toBeLessThan(keys.indexOf("ddl:table:quote.task"));
    expect(keys.indexOf("ddl:table:quote.note")).toBeLessThan(keys.indexOf("ddl:fk:quote.task.note_id"));
    expect(keys.indexOf("ddl:table:quote.task")).toBeLessThan(keys.indexOf("ddl:fk:quote.task.note_id"));
    expect(keys.indexOf("ddl:fk:quote.task.note_id")).toBeLessThan(keys.indexOf("function:quote.task_create"));
  });

  it("fails with an explicit cycle on mutually dependent functions", async () => {
    const root = await createWorkspace();
    await writeDependencyModule(
      root,
      "quote",
      `
module quote

fn quote.alpha() -> int [stable]:
  return quote.beta()

fn quote.beta() -> int [stable]:
  return quote.alpha()
`,
    );

    const workflow = await prepareModuleWorkflow(root, "quote");
    expect(() => sortApplyArtifacts(workflow.artifacts)).toThrow(
      "artifact dependency cycle detected: function quote.alpha -> function quote.beta -> function quote.alpha",
    );
  });

  it("runs module i18n_seed when present", async () => {
    const queries: Array<{ sql: string; params?: unknown[] }> = [];
    const client: DbClient = {
      async query<T = Record<string, unknown>>(sql: string, params?: unknown[]) {
        queries.push({ sql, params });
        if (sql.includes("FROM pg_proc")) return { rows: [{ present: 1 }] as T[], rowCount: 1 };
        return { rows: [] as T[], rowCount: 0 };
      },
    };

    const seeded = await runModuleI18nSeed(client, {
      name: "quote",
      version: "0.1.0",
      description: "Quote",
      plx: { entry: "src/quote.plx" },
    });

    expect(seeded).toBe("seeded i18n quote.i18n_seed()");
    expect(queries).toEqual([
      expect.objectContaining({
        sql: expect.stringContaining("FROM pg_proc"),
        params: ["quote"],
      }),
      expect.objectContaining({
        sql: 'SELECT "quote".i18n_seed()',
      }),
    ]);
  });

  it("skips module i18n_seed when absent", async () => {
    const queries: Array<{ sql: string; params?: unknown[] }> = [];
    const client: DbClient = {
      async query<T = Record<string, unknown>>(sql: string, params?: unknown[]) {
        queries.push({ sql, params });
        return { rows: [] as T[], rowCount: 0 };
      },
    };

    const seeded = await runModuleI18nSeed(client, {
      name: "quote",
      version: "0.1.0",
      description: "Quote",
      plx: { entry: "src/quote.plx" },
    });

    expect(seeded).toBeUndefined();
    expect(queries).toHaveLength(1);
    expect(queries[0]).toEqual(
      expect.objectContaining({
        sql: expect.stringContaining("FROM pg_proc"),
        params: ["quote"],
      }),
    );
  });
});
