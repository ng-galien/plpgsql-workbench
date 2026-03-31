import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { compileModule } from "../compiler.js";
import { buildModuleContract } from "../contract.js";
import { loadPlxModule } from "../module-loader.js";

const tmpRoots: string[] = [];

async function createTmpDir(): Promise<string> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "plx-module-loader-"));
  tmpRoots.push(root);
  return root;
}

afterEach(async () => {
  await Promise.all(tmpRoots.splice(0).map((root) => fs.rm(root, { recursive: true, force: true })));
});

describe("PLX module loader", () => {
  it("loads included fragments and applies root exports", async () => {
    const root = await createTmpDir();
    const entry = path.join(root, "quote.plx");

    await fs.writeFile(
      entry,
      `
module quote
depends pgv

include "./brand.plx"
include "./quote.spec.plx"

export quote.brand
`,
      "utf-8",
    );
    await fs.writeFile(
      path.join(root, "brand.plx"),
      `
fn quote.brand() -> text [stable]:
  return 'Quote'
`,
      "utf-8",
    );
    await fs.writeFile(
      path.join(root, "quote.spec.plx"),
      `
test "brand":
  label := quote.brand()
  assert label = 'Quote'
`,
      "utf-8",
    );

    const loaded = await loadPlxModule(entry);
    expect(loaded.errors).toEqual([]);
    expect(loaded.module?.functions).toHaveLength(1);
    expect(loaded.module?.tests).toHaveLength(1);
    const mod = loaded.module;
    if (!mod) throw new Error("expected loaded module");

    const contract = buildModuleContract(mod);
    expect(contract.moduleName).toBe("quote");
    expect(contract.exports).toEqual([
      expect.objectContaining({
        schema: "quote",
        name: "brand",
        visibility: "export",
      }),
    ]);

    const result = compileModule(mod);
    expect(result.errors).toEqual([]);
    expect(result.sql).toContain("quote.brand");
    expect(result.testSql).toContain("quote_ut.test_brand");
  });

  it("errors when the module root exports an unknown symbol", async () => {
    const root = await createTmpDir();
    const entry = path.join(root, "quote.plx");

    await fs.writeFile(
      entry,
      `
module quote

include "./brand.plx"

export quote.missing
`,
      "utf-8",
    );
    await fs.writeFile(
      path.join(root, "brand.plx"),
      `
fn quote.brand() -> text [stable]:
  return 'Quote'
`,
      "utf-8",
    );

    const loaded = await loadPlxModule(entry);
    expect(loaded.module).toBeUndefined();
    expect(loaded.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "module.unknown-export",
          file: entry,
        }),
      ]),
    );
  });

  it("errors when an included fragment uses root-only directives", async () => {
    const root = await createTmpDir();
    const entry = path.join(root, "quote.plx");
    const fragment = path.join(root, "brand.plx");

    await fs.writeFile(
      entry,
      `
module quote
include "./brand.plx"
export quote.brand
`,
      "utf-8",
    );
    await fs.writeFile(
      fragment,
      `
module brand

fn quote.brand() -> text [stable]:
  return 'Quote'
`,
      "utf-8",
    );

    const loaded = await loadPlxModule(entry);
    expect(loaded.module).toBeUndefined();
    expect(loaded.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "parse.fragment-root-only-directive",
          file: fragment,
        }),
      ]),
    );
  });
});
