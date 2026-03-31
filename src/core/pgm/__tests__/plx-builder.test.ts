import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { installModules } from "../installer.js";
import { buildPlxModule } from "../plx-builder.js";
import { loadManifest, resolve } from "../resolver.js";

const tmpRoots: string[] = [];

async function createWorkspace(): Promise<string> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "pgm-plx-build-"));
  tmpRoots.push(root);
  await fs.mkdir(path.join(root, "modules"), { recursive: true });
  return root;
}

async function writeModule(
  root: string,
  name: string,
  manifest: Record<string, unknown>,
  plxSource: string,
): Promise<void> {
  const moduleDir = path.join(root, "modules", name);
  await fs.mkdir(path.join(moduleDir, "src"), { recursive: true });
  await fs.writeFile(path.join(moduleDir, "module.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf-8");
  await fs.writeFile(path.join(moduleDir, "src", `${name}.plx`), plxSource, "utf-8");
}

afterEach(async () => {
  await Promise.all(tmpRoots.splice(0).map((root) => fs.rm(root, { recursive: true, force: true })));
});

describe("pgm PLX build integration", () => {
  it("builds declared PLX artifacts into module build files", async () => {
    const root = await createWorkspace();
    await writeModule(
      root,
      "quote",
      {
        name: "quote",
        version: "0.1.0",
        description: "Quote",
        schemas: { public: "quote", private: null },
        dependencies: [],
        extensions: [],
        sql: ["build/quote.ddl.sql", "build/quote.func.sql", "build/quote_ut.func.sql"],
        assets: {},
        grants: {},
        plx: { entry: "src/quote.plx" },
      },
      `
module quote

export fn quote.estimate_read(id int) -> jsonb:
  return {id}

test "estimate read":
  row := quote.estimate_read(1)
  assert row->>'id' = '1'
`,
    );

    const modulesDir = path.join(root, "modules");
    const manifest = await loadManifest(modulesDir, "quote");
    const result = await buildPlxModule(modulesDir, manifest, { validate: false });

    expect(result.files).toEqual(["build/quote.ddl.sql", "build/quote.func.sql", "build/quote_ut.func.sql"]);
    await expect(fs.readFile(path.join(modulesDir, "quote", "build", "quote.ddl.sql"), "utf-8")).resolves.toContain(
      'CREATE SCHEMA IF NOT EXISTS "quote"',
    );
    await expect(fs.readFile(path.join(modulesDir, "quote", "build", "quote.func.sql"), "utf-8")).resolves.toContain(
      "quote.estimate_read",
    );
    await expect(fs.readFile(path.join(modulesDir, "quote", "build", "quote_ut.func.sql"), "utf-8")).resolves.toContain(
      "quote_ut.test_estimate_read",
    );
  });

  it("auto-builds PLX modules before install copies SQL files", async () => {
    const root = await createWorkspace();
    await writeModule(
      root,
      "quote",
      {
        name: "quote",
        version: "0.1.0",
        description: "Quote",
        schemas: { public: "quote", private: null },
        dependencies: [],
        extensions: [],
        sql: ["build/quote.ddl.sql", "build/quote.func.sql"],
        assets: {},
        grants: {},
        plx: { entry: "src/quote.plx" },
      },
      `
module quote

export fn quote.estimate_read(id int) -> jsonb:
  return {id}
`,
    );

    const appDir = path.join(root, "apps", "demo");
    await fs.mkdir(path.join(appDir, "sql"), { recursive: true });
    await fs.mkdir(path.join(appDir, "frontend"), { recursive: true });

    const modulesDir = path.join(root, "modules");
    const plan = await resolve(modulesDir, ["quote"]);
    const results = await installModules(modulesDir, appDir, plan);

    // PLX build generates build/quote.ddl.sql + build/quote.func.sql, then install copies both.
    expect(results[0]?.files).toEqual(expect.arrayContaining(["sql/05-quote.ddl.sql", "sql/05-quote.func.sql"]));
    await expect(fs.readFile(path.join(appDir, "sql", "05-quote.func.sql"), "utf-8")).resolves.toContain(
      "quote.estimate_read",
    );
  });
});
