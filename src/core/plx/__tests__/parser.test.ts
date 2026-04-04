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

  it("tokenizes and parses boolean literals as booleans", () => {
    const tokens = tokenize(`
fn demo.flags(done boolean = true) -> void:
  assert false
`);
    expect(tokens.some((token) => token.type === "BOOLEAN" && token.value === "true")).toBe(true);
    expect(tokens.some((token) => token.type === "BOOLEAN" && token.value === "false")).toBe(true);

    const mod = parse(tokens);
    expect(mod.functions[0]?.params[0]).toEqual(expect.objectContaining({ defaultValue: "true" }));
    expect(mod.functions[0]?.body[0]).toEqual(
      expect.objectContaining({
        kind: "assert",
        expression: expect.objectContaining({ kind: "literal", type: "boolean", value: false }),
      }),
    );
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

  it("parses named arguments in call expressions", () => {
    const mod = parse(
      tokenize(`
fn demo.run() -> jsonb:
  return demo.classify(p_id := 7, p_title := 'Test')
`),
    );

    const call = mod.functions[0]?.body[0];
    expect(call).toEqual(
      expect.objectContaining({
        kind: "return",
        value: expect.objectContaining({
          kind: "call",
          name: "demo.classify",
          args: [expect.objectContaining({ name: "p_id" }), expect.objectContaining({ name: "p_title" })],
        }),
      }),
    );
  });

  it("parses cast targets with array suffixes", () => {
    const mod = parse(
      tokenize(`
fn demo.arr() -> void:
  values := '{jazz,concert}'::text[]
`),
    );

    expect(mod.functions[0]?.body[0]).toEqual(
      expect.objectContaining({
        kind: "assign",
        value: expect.objectContaining({
          kind: "binary",
          op: "::",
          right: expect.objectContaining({ kind: "identifier", name: "text[]" }),
        }),
      }),
    );
  });

  it("parses entity events, lifecycle hooks, emit statements and subscriptions", () => {
    const mod = parse(
      tokenize(`
module purchase
depends stock

entity purchase.receipt:
  fields:
    supplier_id int
    status text

  event received(receipt_id int, supplier_id int)

  on update(new, old):
    if old.status = 'draft' and new.status = 'received':
      emit received(new.id, new.supplier_id)

on purchase.receipt.received(receipt_id, supplier_id):
  stock.create_movement(receipt_id, supplier_id)
`),
    );

    expect(mod.entities[0]?.events).toEqual([
      expect.objectContaining({
        name: "received",
        params: [
          expect.objectContaining({ name: "receipt_id", type: "int" }),
          expect.objectContaining({ name: "supplier_id", type: "int" }),
        ],
      }),
    ]);
    expect(mod.entities[0]?.changeHandlers).toEqual([
      expect.objectContaining({
        operation: "update",
        params: ["new", "old"],
        body: [
          expect.objectContaining({
            kind: "if",
            body: [
              expect.objectContaining({
                kind: "emit",
                eventName: "received",
              }),
            ],
          }),
        ],
      }),
    ]);
    expect(mod.subscriptions).toEqual([
      expect.objectContaining({
        sourceSchema: "purchase",
        sourceEntity: "receipt",
        event: "received",
        params: ["receipt_id", "supplier_id"],
      }),
    ]);
  });

  it("parses view template field objects", () => {
    const mod = parse(
      tokenize(`
entity demo.task:
  fields:
    title text required
    status text

  view:
    compact: [{key: title, label: demo.field_title}]
    standard:
      fields: [title, {key: status, type: status, label: demo.field_status}]
`),
    );

    expect(mod.entities[0]?.view.compact).toEqual([
      expect.objectContaining({ key: "title", label: "demo.field_title" }),
    ]);
    expect(mod.entities[0]?.view.standard?.fields).toEqual([
      "title",
      expect.objectContaining({ key: "status", type: "status", label: "demo.field_status" }),
    ]);
  });

  it("rejects unsupported entity change hook names", () => {
    const error = parseErrorOf(`
entity demo.task:
  fields:
    title text required

  on change(new, old):
    emit renamed(new.id)
`);
    expect(error).toMatchObject({ code: "parse.invalid-entity-change-hook" });
    expect(error.message).toContain("unsupported entity change hook 'change'");
  });

  it("rejects before/after delete hooks and accepts validate delete", () => {
    const beforeDelete = parseErrorOf(`
entity demo.task:
  fields:
    title text required

  before delete:
    assert true
`);
    expect(beforeDelete).toMatchObject({ code: "parse.invalid-entity-hook-action" });
    expect(beforeDelete.message).toContain("before delete hooks are not supported");

    const mod = parse(
      tokenize(`
entity demo.task:
  fields:
    title text required

  validate delete:
    assert true
`),
    );
    expect(mod.entities[0]?.hooks).toEqual([
      expect.objectContaining({
        event: "validate_delete",
        params: [],
      }),
    ]);
  });

  it("parses IS NULL and IS NOT NULL as postfix operators", () => {
    const mod = parse(
      tokenize(`
fn demo.check(p_val text) -> text:
  if p_val is null:
    return 'null'
  if p_val is not null:
    return 'present'
  return 'unknown'
`),
    );

    const body = mod.functions[0]?.body ?? [];
    // First if: p_val is null → binary { op: "IS NULL", left: p_val, right: null }
    const if1 = body[0];
    expect(if1).toMatchObject({
      kind: "if",
      condition: {
        kind: "binary",
        op: "IS NULL",
        left: expect.objectContaining({ kind: "identifier", name: "p_val" }),
        right: expect.objectContaining({ kind: "literal", value: null }),
      },
    });
    // Second if: p_val is not null → binary { op: "IS NOT NULL", left: p_val, right: null }
    const if2 = body[1];
    expect(if2).toMatchObject({
      kind: "if",
      condition: {
        kind: "binary",
        op: "IS NOT NULL",
        left: expect.objectContaining({ kind: "identifier", name: "p_val" }),
        right: expect.objectContaining({ kind: "literal", value: null }),
      },
    });
  });

  it("rejects legacy return query syntax", () => {
    expect(
      parseErrorOf(`
fn quote.read() -> setof jsonb:
  return query select to_jsonb(1)
`),
    ).toMatchObject({ code: "parse.legacy-return-mode" });
  });

  it("parses try/catch blocks", () => {
    const mod = parse(
      tokenize(`
fn demo.safe(p_id int) -> boolean:
  ok := false
  try:
    demo.risky_call(p_id)
    ok := true
  catch:
    ok := false
  return ok
`),
    );

    const body = mod.functions[0]?.body ?? [];
    const tryCatch = body[1]; // after ok := false
    expect(tryCatch).toMatchObject({
      kind: "try_catch",
      body: expect.arrayContaining([expect.objectContaining({ kind: "assign", target: "ok" })]),
      catchBody: expect.arrayContaining([expect.objectContaining({ kind: "assign", target: "ok" })]),
    });
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
