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
});
