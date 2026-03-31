import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { loadManifest, resolve } from "../resolver.js";

const tmpRoots: string[] = [];

async function createWorkspace(): Promise<string> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "pgm-resolver-"));
  tmpRoots.push(root);
  await fs.mkdir(path.join(root, "modules"), { recursive: true });
  return root;
}

async function writeModule(
  root: string,
  name: string,
  manifest: Record<string, unknown>,
  plxSource?: string,
): Promise<void> {
  const moduleDir = path.join(root, "modules", name);
  await fs.mkdir(moduleDir, { recursive: true });
  await fs.writeFile(path.join(moduleDir, "module.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf-8");
  if (plxSource) {
    await fs.mkdir(path.join(moduleDir, "src"), { recursive: true });
    await fs.writeFile(path.join(moduleDir, "src", `${name}.plx`), plxSource, "utf-8");
  }
}

afterEach(async () => {
  await Promise.all(tmpRoots.splice(0).map((root) => fs.rm(root, { recursive: true, force: true })));
});

describe("pgm resolver with PLX contracts", () => {
  it("loads manifests whose dependencies cover the PLX contract", async () => {
    const root = await createWorkspace();
    await writeModule(
      root,
      "crm",
      {
        name: "crm",
        version: "0.1.0",
        description: "CRM",
        schemas: { public: "crm", private: null },
        dependencies: [],
        extensions: [],
        sql: ["build/crm.func.sql"],
        assets: {},
        grants: {},
        plx: { entry: "src/crm.plx" },
      },
      `
module crm

export fn crm.client_read(id int) -> jsonb:
  return {id}
`,
    );
    await writeModule(
      root,
      "quote",
      {
        name: "quote",
        version: "0.1.0",
        description: "Quote",
        schemas: { public: "quote", private: null },
        dependencies: ["crm"],
        extensions: [],
        sql: ["build/quote.func.sql"],
        assets: {},
        grants: {},
        plx: { entry: "src/quote.plx" },
      },
      `
module quote
depends crm

export fn quote.estimate_read(id int) -> jsonb:
  return crm.client_read(id)
`,
    );

    const manifest = await loadManifest(path.join(root, "modules"), "quote");
    expect(manifest.plxContract?.moduleName).toBe("quote");
    expect(manifest.plxContract?.depends).toEqual(["crm"]);

    const plan = await resolve(path.join(root, "modules"), ["quote"]);
    expect(plan.order.map((mod) => mod.name)).toEqual(["crm", "quote"]);
  });

  it("rejects manifests whose dependencies drift from PLX depends", async () => {
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
        sql: ["build/quote.func.sql"],
        assets: {},
        grants: {},
        plx: { entry: "src/quote.plx" },
      },
      `
module quote
depends crm

export fn quote.estimate_read(id int) -> jsonb:
  return 1
`,
    );

    await expect(loadManifest(path.join(root, "modules"), "quote")).rejects.toThrow(/must include PLX depends: crm/);
  });

  it("rejects manifests whose PLX module name drifts from module.json", async () => {
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
        sql: ["build/quote.func.sql"],
        assets: {},
        grants: {},
        plx: { entry: "src/quote.plx" },
      },
      `
module crm

export fn crm.client_read(id int) -> jsonb:
  return {id}
`,
    );

    await expect(loadManifest(path.join(root, "modules"), "quote")).rejects.toThrow(
      /PLX module 'crm' does not match manifest name 'quote'/,
    );
  });
});
