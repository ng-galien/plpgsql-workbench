import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../../../..");
const CLI = path.resolve(REPO_ROOT, "src/core/plx/cli.ts");
const FIXTURES = path.resolve(REPO_ROOT, "fixtures/plx");

describe("plx cli", () => {
  it("emits machine-readable JSON for successful checks", () => {
    const output = execFileSync(
      "node",
      ["--import", "tsx", CLI, "check", "--json", "--no-validate", path.join(FIXTURES, "client_read.plx")],
      {
        cwd: REPO_ROOT,
        encoding: "utf-8",
      },
    );

    const payload = JSON.parse(output) as {
      errors: unknown[];
      file: string;
      functionCount: number;
      ok: boolean;
      warnings: unknown[];
    };

    expect(payload.ok).toBe(true);
    expect(payload.file).toBe(path.join(FIXTURES, "client_read.plx"));
    expect(payload.functionCount).toBeGreaterThan(0);
    expect(payload.errors).toHaveLength(0);
    expect(payload.warnings).toEqual([]);
  });

  it("emits machine-readable JSON for failed checks", async () => {
    const tmpFile = path.join(os.tmpdir(), `plx-cli-${Date.now()}.plx`);
    await fs.writeFile(
      tmpFile,
      `
fn demo.bad() -> text:
  return missing_value
`,
      "utf-8",
    );

    const run = spawnSync("node", ["--import", "tsx", CLI, "check", "--json", "--no-validate", tmpFile], {
      cwd: REPO_ROOT,
      encoding: "utf-8",
    });

    expect(run.status).toBe(1);
    expect(run.stderr).toBe("");

    const payload = JSON.parse(run.stdout) as {
      errors: Array<{ code: string; hint?: string; phase: string }>;
      ok: boolean;
    };

    expect(payload.ok).toBe(false);
    expect(payload.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          phase: "semantic",
          code: "semantic.unknown-identifier",
        }),
      ]),
    );
    expect(payload.errors[0]?.hint).toContain("Declare the variable first");
  });

  it("emits machine-readable JSON for composed module checks", async () => {
    const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "plx-compose-"));
    const crmFile = path.join(tmpDir, "crm.plx");
    const quoteFile = path.join(tmpDir, "quote.plx");

    await fs.writeFile(
      crmFile,
      `
module crm

export fn crm.client_read(id int) -> jsonb:
  return {id}
`,
      "utf-8",
    );
    await fs.writeFile(
      quoteFile,
      `
module quote
depends crm

export fn quote.estimate_read(id int) -> jsonb:
  return crm.client_read(id)
`,
      "utf-8",
    );

    const output = execFileSync(
      "node",
      ["--import", "tsx", CLI, "compose", "--json", "--no-validate", crmFile, quoteFile],
      {
        cwd: REPO_ROOT,
        encoding: "utf-8",
      },
    );

    const payload = JSON.parse(output) as {
      errors: unknown[];
      moduleCount: number;
      ok: boolean;
      warnings: unknown[];
    };

    expect(payload.ok).toBe(true);
    expect(payload.moduleCount).toBe(2);
    expect(payload.errors).toEqual([]);
    expect(payload.warnings).toEqual([]);
  });

  it("checks a multi-file module entry with included fragments", async () => {
    const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "plx-cli-multi-"));
    const entry = path.join(tmpDir, "quote.plx");

    await fs.writeFile(
      entry,
      `
module quote

include "./brand.plx"
include "./quote.spec.plx"

export quote.brand
`,
      "utf-8",
    );
    await fs.writeFile(
      path.join(tmpDir, "brand.plx"),
      `
fn quote.brand() -> text [stable]:
  return 'Quote'
`,
      "utf-8",
    );
    await fs.writeFile(
      path.join(tmpDir, "quote.spec.plx"),
      `
test "brand":
  label := quote.brand()
  assert label = 'Quote'
`,
      "utf-8",
    );

    const output = execFileSync("node", ["--import", "tsx", CLI, "check", "--json", "--no-validate", entry], {
      cwd: REPO_ROOT,
      encoding: "utf-8",
    });

    const payload = JSON.parse(output) as {
      errors: unknown[];
      functionCount: number;
      ok: boolean;
      testCount: number;
    };

    expect(payload.ok).toBe(true);
    expect(payload.functionCount).toBe(1);
    expect(payload.testCount).toBe(1);
    expect(payload.errors).toEqual([]);
  });
});
