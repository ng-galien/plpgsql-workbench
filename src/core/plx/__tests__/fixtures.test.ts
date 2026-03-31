import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { compile } from "../compiler.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FIXTURES = path.resolve(__dirname, "../../../../fixtures/plx");

describe("PLX fixture coverage", () => {
  it("matches the golden SQL for client_read.plx", async () => {
    const source = await fs.readFile(path.join(FIXTURES, "client_read.plx"), "utf-8");
    const expected = await fs.readFile(path.join(FIXTURES, "client_read.expected.sql"), "utf-8");
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql.trim()).toBe(expected.trim());
  });

  it("compiles every .plx fixture without semantic/codegen errors", async () => {
    const files = (await fs.readdir(FIXTURES)).filter((name) => name.endsWith(".plx")).sort();

    for (const file of files) {
      const source = await fs.readFile(path.join(FIXTURES, file), "utf-8");
      const result = compile(source);
      expect(result.errors, file).toHaveLength(0);
    }
  });
});
