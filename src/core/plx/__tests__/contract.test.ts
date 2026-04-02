import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { pointLoc } from "../ast.js";
import { buildModuleContract, readModuleContract, readModuleContractEntry, toContractError } from "../contract.js";
import { buildModuleFromSource } from "../module-loader.js";

const tmpRoots: string[] = [];

async function createTmpDir(): Promise<string> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "plx-contract-"));
  tmpRoots.push(root);
  return root;
}

afterEach(async () => {
  await Promise.all(tmpRoots.splice(0).map((root) => fs.rm(root, { recursive: true, force: true })));
});

describe("PLX contract helpers", () => {
  it("builds exports, internals and depends from a module", () => {
    const loaded = buildModuleFromSource(`
module quote
depends crm, pgv

export fn quote.read() -> jsonb:
  return {}

internal fn quote.helper() -> text:
  return 'ok'

entity quote.task:
  fields:
    title text required

  event accepted(task_id int, status text)
`);
    if (!loaded.module) throw new Error("expected module");

    const contract = buildModuleContract(loaded.module);
    expect(contract.moduleName).toBe("quote");
    expect(contract.depends).toEqual(["crm", "pgv"]);
    expect(contract.exports).toEqual([
      expect.objectContaining({
        kind: "function",
        schema: "quote",
        name: "read",
        visibility: "export",
        params: [],
        returnType: "jsonb",
        setof: false,
      }),
    ]);
    expect(contract.internals).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          kind: "function",
          schema: "quote",
          name: "helper",
          visibility: "internal",
          params: [],
          returnType: "text",
          setof: false,
        }),
        expect.objectContaining({ kind: "entity", schema: "quote", name: "task", visibility: "internal" }),
        expect.objectContaining({
          kind: "event",
          schema: "quote",
          name: "task.accepted",
          visibility: "internal",
          params: expect.arrayContaining([expect.objectContaining({ name: "task_id", type: "int" })]),
        }),
      ]),
    );
    expect(contract.spans.module).toBeDefined();
  });

  it("returns parse errors from readModuleContract", () => {
    const result = readModuleContract(`
module quote

fn quote.bad( -> int:
`);
    expect(result.contract).toBeUndefined();
    expect(result.errors).toEqual(
      expect.arrayContaining([expect.objectContaining({ code: "parse.unexpected-token", phase: "parse" })]),
    );
  });

  it("loads a module contract from an entry file", async () => {
    const root = await createTmpDir();
    const entry = path.join(root, "quote.plx");
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
      path.join(root, "brand.plx"),
      `
fn quote.brand() -> text [stable]:
  return 'Quote'
`,
      "utf-8",
    );

    const result = await readModuleContractEntry(entry);
    expect(result.errors).toEqual([]);
    expect(result.contract).toMatchObject({
      moduleName: "quote",
      exports: [expect.objectContaining({ name: "brand", schema: "quote" })],
    });
  });

  it("normalizes thrown errors with loc objects", () => {
    const error = Object.assign(new Error("boom"), {
      code: "parse.custom",
      loc: {
        file: "x.plx",
        line: 4,
        col: 2,
        endLine: 4,
        endCol: 5,
      },
    });

    expect(toContractError("parse", error, "fallback")).toMatchObject({
      code: "parse.custom",
      file: "x.plx",
      line: 4,
      col: 2,
    });
  });

  it("normalizes thrown errors with line/col or plain messages", () => {
    const positional = Object.assign(new Error("broken"), {
      code: "lex.custom",
      file: "y.plx",
      line: 2,
      col: 7,
      endLine: 2,
      endCol: 8,
      hint: "fix it",
    });
    expect(toContractError("lex", positional, "fallback")).toMatchObject({
      code: "lex.custom",
      file: "y.plx",
      line: 2,
      col: 7,
      hint: "fix it",
    });

    expect(toContractError("parse", new Error("plain"), "fallback", pointLoc(9, 3))).toMatchObject({
      code: "fallback",
      line: 9,
      col: 3,
      message: "plain",
    });

    expect(toContractError("parse", "raw failure", "fallback", pointLoc(5, 6))).toMatchObject({
      code: "fallback",
      line: 5,
      col: 6,
      message: "raw failure",
    });
  });
});
