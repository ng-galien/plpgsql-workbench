import { describe, expect, it } from "vitest";
import { tokenize } from "../lexer.js";
import { ParseError } from "../parse-context.js";
import { parse } from "../parser.js";

function parseErrorOf(source: string, options?: Parameters<typeof parse>[1]): ParseError {
  try {
    parse(tokenize(source), options);
    throw new Error("expected parse to throw");
  } catch (error: unknown) {
    expect(error).toBeInstanceOf(ParseError);
    return error as ParseError;
  }
}

describe("PLX parser", () => {
  it("parses module directives, imports, traits, and full function signatures", () => {
    const mod = parse(
      tokenize(`
module quote
depends crm, pgv
include "./brand.plx"
export quote.read
import crm.client_read as read_client

trait audit:
  fields:
    created_at timestamptz
    updated_at timestamptz default(now())
  default_scope: tenant

export fn quote.read(id int, label text? = 'draft', count int = 1, fallback text? = null, tags text[]) -> setof jsonb [stable, strict]:
  return []
`),
    );

    expect(mod.name).toBe("quote");
    expect(mod.depends.map((dep) => dep.name)).toEqual(["crm", "pgv"]);
    expect(mod.includes.map((include) => include.path)).toEqual(["./brand.plx"]);
    expect(mod.exports.map((entry) => entry.name)).toEqual(["quote.read"]);
    expect(mod.imports).toEqual([expect.objectContaining({ original: "crm.client_read", alias: "read_client" })]);
    expect(mod.traits).toEqual([
      expect.objectContaining({
        name: "audit",
        defaultScope: "tenant",
        fields: [
          expect.objectContaining({ name: "created_at", type: "timestamptz", nullable: false }),
          expect.objectContaining({ name: "updated_at", type: "timestamptz", defaultValue: "now ( )" }),
        ],
      }),
    ]);
    expect(mod.functions).toEqual([
      expect.objectContaining({
        visibility: "export",
        schema: "quote",
        name: "read",
        setof: true,
        returnType: "jsonb",
        attributes: ["stable", "strict"],
        params: [
          expect.objectContaining({ name: "id", type: "int", nullable: false }),
          expect.objectContaining({ name: "label", type: "text", nullable: true, defaultValue: "'draft'" }),
          expect.objectContaining({ name: "count", type: "int", defaultValue: "1" }),
          expect.objectContaining({ name: "fallback", type: "text", nullable: true, defaultValue: "NULL::text" }),
          expect.objectContaining({ name: "tags", type: "text[]", nullable: false }),
        ],
      }),
    ]);
  });

  it("errors when depends/include/export are declared before module", () => {
    expect(parseErrorOf("depends crm")).toMatchObject({ code: "parse.depends-without-module" });
    expect(parseErrorOf('include "./brand.plx"')).toMatchObject({ code: "parse.include-without-module" });
    expect(parseErrorOf("export quote.read")).toMatchObject({ code: "parse.export-without-module" });
  });

  it("errors on invalid root exports", () => {
    const error = parseErrorOf(`
module quote
export quote
`);
    expect(error).toMatchObject({ code: "parse.invalid-export-name" });
    expect(error.hint).toContain("export schema.symbol");
  });

  it("errors on invalid visibility targets and unknown function attributes", () => {
    expect(
      parseErrorOf(`
internal trait audit:
  fields:
    created_at timestamptz
`),
    ).toMatchObject({ code: "parse.invalid-visibility-target" });

    expect(
      parseErrorOf(`
internal test "bad":
  assert true
`),
    ).toMatchObject({ code: "parse.invalid-visibility-target" });

    expect(
      parseErrorOf(`
fn quote.read() -> jsonb [cached]:
  return []
`),
    ).toMatchObject({ code: "parse.unknown-function-attribute" });
  });

  it("parses triple-quoted SQL in return and assert contexts", () => {
    const mod = parse(
      tokenize(`
fn quote.read(id int) -> jsonb:
  result := """
    select jsonb_build_object('id', id)
  """
  assert """
    select result is not null
  """
  return """
    select result
  """
`),
    );

    expect(mod.functions[0]?.body).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ kind: "assign", value: expect.objectContaining({ kind: "sql_block" }) }),
        expect.objectContaining({ kind: "assert", expression: expect.objectContaining({ kind: "sql_block" }) }),
        expect.objectContaining({ kind: "return", value: expect.objectContaining({ kind: "sql_block" }) }),
      ]),
    );
  });

  it("rejects legacy return query syntax", () => {
    expect(
      parseErrorOf(`
fn quote.read() -> setof jsonb:
  return query select to_jsonb(1)
`),
    ).toMatchObject({ code: "parse.legacy-return-mode" });
  });

  it("rejects root-only directives and visibility markers inside fragments", () => {
    expect(
      parseErrorOf(
        `
module quote
`,
        { kind: "fragment" },
      ),
    ).toMatchObject({ code: "parse.fragment-root-only-directive" });

    expect(
      parseErrorOf(
        `
export fn quote.read() -> jsonb:
  return []
`,
        { kind: "fragment" },
      ),
    ).toMatchObject({ code: "parse.fragment-visibility" });

    expect(
      parseErrorOf(
        `
internal fn quote.read() -> jsonb:
  return []
`,
        { kind: "fragment" },
      ),
    ).toMatchObject({ code: "parse.fragment-visibility" });
  });
});
