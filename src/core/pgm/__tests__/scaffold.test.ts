import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { scaffoldModule } from "../scaffold.js";

const tmpRoots: string[] = [];

async function createTmpRoot(): Promise<string> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "pgm-scaffold-"));
  tmpRoots.push(root);
  return root;
}

afterEach(async () => {
  await Promise.all(tmpRoots.splice(0).map((root) => fs.rm(root, { recursive: true, force: true })));
});

describe("pgm scaffold", () => {
  it("creates a PLX-first module scaffold", async () => {
    const root = await createTmpRoot();
    const moduleDir = path.join(root, "quote");

    const created = await scaffoldModule(moduleDir, "quote", "quote", 3100, {
      description: "Quote module",
      mode: "plx",
    });

    expect(created).toEqual(
      expect.arrayContaining([
        "module.json",
        "build/quote.ddl.sql",
        "build/quote.func.sql",
        "build/quote_ut.func.sql",
        "src/quote.plx",
        "CLAUDE.md",
      ]),
    );

    const manifest = JSON.parse(await fs.readFile(path.join(moduleDir, "module.json"), "utf-8")) as {
      plx?: { entry: string };
      sql: string[];
    };
    expect(manifest.plx).toEqual({ entry: "src/quote.plx" });
    expect(manifest.sql).toEqual(["build/quote.ddl.sql", "build/quote.func.sql", "build/quote_ut.func.sql"]);

    const source = await fs.readFile(path.join(moduleDir, "src", "quote.plx"), "utf-8");
    expect(source).toContain("module quote");
    expect(source).toContain("depends pgv");
    expect(source).toContain("export fn quote.health() -> jsonb [stable]:");
    expect(source).toContain('return {name: "quote", status: "ok"}');

    const claude = await fs.readFile(path.join(moduleDir, "CLAUDE.md"), "utf-8");
    expect(claude).toContain("pgm module build quote");
    expect(claude).toContain("src/quote.plx");
  });

  it("rejects PLX scaffolds when schema differs from the module name", async () => {
    const root = await createTmpRoot();
    const moduleDir = path.join(root, "billing");

    await expect(
      scaffoldModule(moduleDir, "billing", "bill", 3100, {
        mode: "plx",
      }),
    ).rejects.toThrow("PLX scaffold currently requires the public schema to match the module name");
  });
});
