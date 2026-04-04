import * as pgParser from "@libpg-query/parser";
import { afterEach, describe, expect, it, vi } from "vitest";
import { pointLoc } from "../ast.js";
import { generateWithSourceMap } from "../codegen.js";
import { compile, compileAndValidate, compileModule, validateCompiledBundle } from "../compiler.js";
import { tokenize } from "../lexer.js";
import { parse } from "../parser.js";

type ValidationBundle = Parameters<typeof validateCompiledBundle>[0];

function makeValidationBundle(
  result: Partial<ValidationBundle["result"]> = {},
  blocks: ValidationBundle["blocks"] = [],
): ValidationBundle {
  return {
    result: {
      sql: "",
      errors: [],
      warnings: [],
      functionCount: 0,
      ...result,
    },
    blocks,
    artifact: {
      aliases: new Map(),
      ddlArtifacts: [],
      functions: [],
      module: parse(tokenize("module demo")),
      testFunctions: [],
    },
  };
}

describe("PLX test compilation", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("compiles a basic test block to pgTAP function", () => {
    const source = `
test "simple call":
  x := myschema.get_value()
  assert x = 42
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testCount).toBe(1);
    expect(result.testSql).toContain("test_simple_call");
    expect(result.testSql).toContain("RETURNS SETOF text");
    expect(result.testSql).toContain("RETURN NEXT is(");
  });

  it("compiles assert != to isnt()", () => {
    const source = `
test "not equal":
  x := expense.get_status(1)
  assert x != 'draft'
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("RETURN NEXT isnt(");
  });

  it("compiles boolean assert to ok()", () => {
    const source = `
test "boolean check":
  n := count(expense.list_items())
  assert n >= 2
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("RETURN NEXT ok(");
  });

  it("emits runtime assertions in regular functions", () => {
    const source = `
fn demo.validate_payload(p_data jsonb) -> void:
  assert jsonb_typeof(p_data) = 'object', demo.err_invalid_payload
  return
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("IF NOT (jsonb_typeof(p_data) = 'object') THEN");
    expect(result.sql).toContain("ERRCODE = 'P0400'");
    expect(result.sql).not.toContain("RETURN NEXT ok(");
  });

  it("infers schema from first qualified call", () => {
    const source = `
test "schema inference":
  r := crm.client_read(1)
  assert r->>'name' = 'Test'
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("crm_ut.test_schema_inference");
    expect(result.ddlSql).toContain('CREATE SCHEMA IF NOT EXISTS "crm_ut";');
  });

  it("errors when no qualified call found", () => {
    const source = `
test "no schema":
  x := 1
  assert x = 1
`;
    const result = compile(source);
    expect(result.errors.length).toBeGreaterThan(0);
    expect(result.errors[0]?.message).toContain("cannot infer schema");
  });

  it("returns lex diagnostics on invalid characters", () => {
    const result = compile(`
fn demo.bad() -> int:
  return $
`);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          phase: "lex",
          code: "lex.unexpected-character",
        }),
      ]),
    );
  });

  it("returns parse diagnostics on invalid syntax", () => {
    const result = compile(`
fn demo.bad( -> int:
`);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          phase: "parse",
          code: "parse.unexpected-token",
        }),
      ]),
    );
  });

  it("does not break existing function compilation", () => {
    const source = `
fn expense.get_total(p_id int) -> numeric:
  result := select sum(amount) from expense.line where report_id = p_id
  return result
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.functionCount).toBe(1);
    expect(result.testCount).toBe(0);
    expect(result.testSql).toBeUndefined();
  });

  it("generates public entity CRUD with jsonb payloads", () => {
    const source = `
entity demo.task:
  fields:
    title text required
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.ddlSql).toContain('CREATE SCHEMA IF NOT EXISTS "demo";');
    expect(result.sql).toContain("FUNCTION demo.task_create(p_input jsonb)");
    expect(result.sql).toContain("FUNCTION demo.task_update(p_id text, p_input jsonb)");
    expect(result.sql).toContain("v_p_row := NULL::demo.task;");
    expect(result.sql).toContain("jsonb_populate_record(v_p_row, p_input)");
    expect(result.sql).toContain("jsonb_populate_record(v_current, p_input)");
    expect(result.sql).toContain("'entity_type', 'crud'");
    expect(result.sql).toContain("'compact'");
    expect(result.sql).toContain("'standard'");
  });

  it("supports fields + payload entities with hybrid storage", () => {
    const source = `
entity demo.task:
  fields:
    rank int? default(0)

  payload:
    title text required
    done boolean? default(false)
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.ddlSql).toContain("payload jsonb NOT NULL DEFAULT '{}'::jsonb");
    expect(result.ddlSql).toContain("rank int DEFAULT 0");
    expect(result.sql).toContain("INSERT INTO demo.task (rank, payload)");
    expect(result.sql).toContain("jsonb_strip_nulls(jsonb_build_object('title'");
    expect(result.sql).toContain("payload = (v_current.payload - array_remove(ARRAY[");
    expect(result.sql).toContain("jsonb_build_object('id', v_result.id, 'rank', v_result.rank)");
  });

  it("preserves empty-string defaults in DDL and create SQL", () => {
    const source = `
entity demo.leave_request:
  fields:
    reason text default('')

  payload:
    note text? default('')
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.ddlSql).toContain("reason text NOT NULL DEFAULT ''");
    expect(result.sql).toContain("COALESCE(v_p_row.reason, '')");
    expect(result.sql).toContain("COALESCE(p_input->'note', to_jsonb(''::text))");
  });

  it("hardens SECURITY DEFINER functions with a fixed search_path", () => {
    const source = `
entity demo.task:
  fields:
    title text required
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.ddlSql).toContain(
      "LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = demo, pg_catalog, pg_temp AS $$",
    );
    expect(result.sql).toContain("SECURITY DEFINER");
    expect(result.sql).toContain("SET search_path = demo, pg_catalog, pg_temp");
  });

  it("generates foreign key constraints for ref(...) fields", () => {
    const source = `
entity demo.note:
  fields:
    title text required

entity demo.task:
  fields:
    note_id int? ref(demo.note)

  payload:
    title text required
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.ddlSql).toContain("CREATE TABLE IF NOT EXISTS demo.note");
    expect(result.ddlSql).toContain("CREATE TABLE IF NOT EXISTS demo.task");
    expect(result.ddlSql).toContain(
      "ALTER TABLE demo.task ADD CONSTRAINT task_note_id_fkey FOREIGN KEY (note_id) REFERENCES demo.note(id);",
    );
  });

  it("supports non-exposed entities without generating public CRUD functions", () => {
    const source = `
entity demo.line:
  expose: false

  fields:
    description text required
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.ddlSql).toContain("CREATE TABLE IF NOT EXISTS demo.line");
    expect(result.sql).not.toContain("demo.line_view");
    expect(result.sql).not.toContain("demo.line_list");
    expect(result.sql).not.toContain("demo.line_read");
    expect(result.sql).not.toContain("demo.line_create");
    expect(result.sql).not.toContain("demo.line_update");
    expect(result.sql).not.toContain("demo.line_delete");
  });

  it("supports generated columns and declarative indexes in entity DDL", () => {
    const source = `
entity demo.asset:
  fields:
    title text required
    description text?
    tags text[]?

  generated:
    search_vec tsvector: """
      setweight(to_tsvector('simple', coalesce(title, '')), 'A') ||
      setweight(to_tsvector('simple', coalesce(description, '')), 'B')
    """

  indexes:
    search:
      using: gin
      on: [search_vec]

    tags:
      using: gin
      on: [tags]

    title_fts:
      using: gin
      on: [to_tsvector('french', coalesce(title, ''))]
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.ddlSql).toContain("search_vec tsvector GENERATED ALWAYS AS (");
    expect(result.ddlSql).toContain(
      "CREATE INDEX IF NOT EXISTS idx_asset_search ON demo.asset USING gin (search_vec);",
    );
    expect(result.ddlSql).toContain("CREATE INDEX IF NOT EXISTS idx_asset_tags ON demo.asset USING gin (tags);");
    expect(result.ddlSql).toContain("CREATE INDEX IF NOT EXISTS idx_asset_title_fts ON demo.asset USING gin (");
    expect(result.ddlSql).toContain("to_tsvector('french',coalesce(title,''))");
  });

  it("runs before create hooks inside generated create functions", () => {
    const source = `
fn demo._next_reference() -> text [stable]:
  return 'NDF-2026-001'

entity demo.report:
  fields:
    reference text?

  before create:
    if p_row.reference is null:
      p_row := jsonb_populate_record(
        p_row,
        {reference: demo._next_reference()}
      )
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("FUNCTION demo.report_create(p_input jsonb)");
    expect(result.sql).toContain("v_p_row := NULL::demo.report;");
    expect(result.sql).toContain("IF v_p_row.reference IS NULL THEN");
    expect(result.sql).toContain("v_p_row := jsonb_populate_record(");
    expect(result.sql).toContain("v_p_row, p_input");
    expect(result.sql).toContain("demo._next_reference()");
    expect(result.sql).toContain("INSERT INTO demo.report");
    expect(result.sql.indexOf("IF v_p_row.reference IS NULL THEN")).toBeLessThan(
      result.sql.indexOf("v_p_row := jsonb_populate_record(v_p_row, p_input);"),
    );
  });

  it("uses custom state columns in generated entity SQL", () => {
    const source = `
entity demo.task:
  fields:
    title text required

  update_states: [draft]

  states draft -> active:
    column: phase
    activate(draft -> active)
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.ddlSql).toContain("phase text NOT NULL DEFAULT 'draft' CHECK (phase IN ('draft', 'active'))");
    expect(result.sql).toContain("v_result->>'phase'");
    expect(result.sql).toContain("WHERE id = p_id::int AND phase = 'draft'");
    expect(result.sql).toContain("SET phase = 'active'");
  });

  it("emits unary NOT for transition guards", () => {
    const source = `
entity demo.task:
  fields:
    title text required

  states draft -> active:
    activate(draft -> active):
      guard: """
        title = 'x'
      """
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("IF NOT (title = 'x') THEN");
    expect(result.sql).not.toContain("IF true NOT");
  });

  it("supports non-linear state transitions when states are declared", () => {
    const source = `
entity demo.report:
  fields:
    title text required

  states draft -> submitted -> validated -> reimbursed -> rejected:
    submit(draft -> submitted)
    validate(submitted -> validated)
    reject(submitted -> rejected)
    reimburse(validated -> reimbursed)

  actions:
    submit: {label: demo.action_submit}
    validate: {label: demo.action_validate}
    reject: {label: demo.action_reject}
    reimburse: {label: demo.action_reimburse}
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("FUNCTION demo.report_reject(p_id text)");
    expect(result.sql).toContain("SET status = 'rejected'");
    expect(result.sql).toContain("UPDATE demo.report SET status = 'rejected'");
    expect(result.sql).toContain("status = 'submitted' RETURNING * INTO v_result");
    expect(result.sql).toContain("'method', 'reject'");
  });

  it("supports triple-quoted SQL in return and assert", () => {
    const source = `
fn demo.list_items() -> setof jsonb:
  return """
    select jsonb_build_object('id', 1)
  """

test "triple quoted assert":
  items := demo.list_items()
  assert """
    select true
  """
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("RETURN QUERY select jsonb_build_object('id', 1);");
    expect(result.testSql).toContain("RETURN NEXT ok((select true), 'assert line 9');");
  });

  it("supports named arguments in regular PLX calls", () => {
    const source = `
fn demo.classify(p_id int, p_title text) -> jsonb [stable]:
  return jsonb_build_object('status', 'classified', 'id', p_id, 'title', p_title)

test "named args":
  id := 7
  result := demo.classify(p_id := id, p_title := 'Test')
  assert result->>'status' = 'classified'
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("v_result := demo.classify(p_id := v_id, p_title := 'Test');");
    expect(result.testSql).toContain("v_result jsonb;");
  });

  it("rewrites local PLX variables inside sql blocks to their plpgsql names", () => {
    const source = `
fn demo.id() -> int [stable]:
  return 1

test "sql block local vars":
  asset_id := demo.id()
  assert """
    select asset_id = 1
  """
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("v_asset_id");
    expect(result.testSql).toContain("select v_asset_id = 1");
    expect(result.testSql).not.toContain("select asset_id = 1");
  });

  it("infers integer variables from cast expressions", () => {
    const source = `
test "cast inference":
  id_seed := demo.id()
  c := jsonb_build_object('id', 7)
  asset_id := (c->>'id')::int
  assert """
    select asset_id = 7
  """
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("v_asset_id integer;");
  });

  it("infers array variables from cast expressions", () => {
    const source = `
fn demo.seed() -> int [stable]:
  return 1

test "array cast inference":
  seed := demo.seed()
  values := '{jazz,concert}'::text[]
  assert """
    select values[1]::text = 'jazz'
  """
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("v_values text[];");
  });

  it("emits cast targets with array suffixes in generated SQL", () => {
    const source = `
fn demo.tags() -> text[] [stable]:
  return '{jazz,concert}'::text[]
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("RETURN '{jazz,concert}'::text[];");
  });

  it("does not rewrite cast targets inside sql blocks", () => {
    const source = `
fn demo.asset_id() -> int [stable]:
  return 1

test "cast target rewrite guard":
  asset_id := demo.asset_id()
  result := """
    select '1'::asset_id
  """
  assert asset_id = 1
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("v_asset_id integer;");
    expect(result.testSql).toContain("select INTO v_result '1'::asset_id");
    expect(result.testSql).not.toContain("::v_asset_id");
  });

  it("infers sql_block select function return types from known functions", () => {
    const source = `
fn demo.classify() -> jsonb [stable]:
  return jsonb_build_object('status', 'classified')

test "sql block call return type":
  seed := demo.classify()
  result := """
    select demo.classify()
  """
  assert result->>'status' = 'classified'
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("v_result jsonb;");
    expect(result.testSql).toContain("select INTO v_result demo.classify()");
  });

  it("supports declarative entity validate rules", () => {
    const source = `
entity demo.task:
  fields:
    title text required

  validate:
    title_present: coalesce(p_input->>'title', '') != ''
    title_not_blank: """
      coalesce(p_input->>'title', '') != ''
    """
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("title_present");
    expect(result.sql).toContain("title_not_blank");
    expect(result.sql).not.toContain("v_p_data := p_patch;");
    expect(result.sql).toContain("coalesce(p_input->>'title', '') != ''");
  });

  it("generates transactional outbox SQL for entity events and subscriptions", () => {
    const source = `
module purchase

entity purchase.receipt:
  fields:
    supplier_id int
    status text

  event received(receipt_id int, supplier_id int)

  on update(new, old):
    if old.status = 'draft' and new.status = 'received':
      emit received(new.id, new.supplier_id)

on purchase.receipt.received(receipt_id, supplier_id):
  purchase.handle_receipt(receipt_id, supplier_id)

fn purchase.handle_receipt(receipt_id int, supplier_id int) -> void:
  return
`;
    const result = compile(source);

    expect(result.errors).toHaveLength(0);
    expect(result.ddlSql).toContain("CREATE TABLE IF NOT EXISTS purchase._event_outbox");
    expect(result.ddlSql).toContain("CREATE TABLE IF NOT EXISTS purchase._event_subscription");
    expect(result.ddlSql).toContain("CREATE TABLE IF NOT EXISTS purchase._event_delivery");
    expect(result.ddlSql).toContain("CREATE OR REPLACE FUNCTION purchase._emit_event(");
    expect(result.ddlSql).toContain("CREATE OR REPLACE FUNCTION purchase._dispatch_event()");
    expect(result.ddlSql).toContain("CREATE OR REPLACE FUNCTION purchase.receipt_event_trigger()");
    expect(result.ddlSql).toContain("INSERT INTO purchase._event_subscription");
    expect(result.ddlSql).toContain("purchase.receipt.received");
    expect(result.sql).toContain("CREATE OR REPLACE FUNCTION purchase.receipt_on_update");
    expect(result.sql).toContain("PERFORM purchase._emit_event('purchase.receipt.received'");
    expect(result.sql).toContain("CREATE OR REPLACE FUNCTION purchase.on_purchase_receipt_received_1");
    expect(result.sql).toContain("PERFORM purchase.handle_receipt(receipt_id, supplier_id);");
  });

  it("compiles mixed functions and tests", () => {
    const source = `
fn expense.helper() -> int:
  return 42

test "uses helper":
  v := expense.helper()
  assert v = 42
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.functionCount).toBe(1);
    expect(result.testCount).toBe(1);
    expect(result.sql).toContain("expense.helper");
    expect(result.testSql).toContain("expense_ut.test_uses_helper");
  });

  it("preserves grouped arithmetic and boolean expressions", () => {
    const source = `
fn demo.math(a int, b int, c int) -> int:
  return a * (b + c)

fn demo.logic(a boolean, b boolean, c boolean) -> boolean:
  return a and (b or c)
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("RETURN a * (b + c);");
    expect(result.sql).toContain("RETURN a AND (b OR c);");
  });

  it("preserves parentheses for same-precedence operators", () => {
    const source = `
fn demo.assoc(a int, b int, c int) -> int:
  return a - (b - c)
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("RETURN a - (b - c);");
  });

  it("supports json arrow access in expressions", () => {
    const source = `
fn demo.json_name(r jsonb) -> jsonb:
  return r->'name'
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("RETURN r->'name';");
  });

  it("allows PLX keywords as bare json object keys", () => {
    const source = `
fn demo.payload() -> jsonb:
  return {entity: 'task', import: 'alias'}
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("jsonb_build_object('entity', 'task', 'import', 'alias')");
  });

  it("supports SQL IN expressions in validate rules", () => {
    const source = `
entity demo.task:
  fields:
    title text required

  validate:
    status_valid: coalesce(p_input->>'status', 'draft') in ('draft', 'active')
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("coalesce(p_input->>'status', 'draft') IN ('draft', 'active')");
  });

  it("returns warnings instead of crashing on PG validation errors", async () => {
    const source = `
fn demo.bad() -> void:
  update broken
`;
    const result = await compileAndValidate(source);
    expect(result.errors).toHaveLength(0);
    expect(result.warnings).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "sql.dml-without-where",
          functionName: "demo.bad",
          line: 3,
          col: 2,
        }),
        expect.objectContaining({
          code: "validate.pg-parse-error",
          functionName: "demo.bad",
          line: 3,
          col: 2,
        }),
      ]),
    );
  });

  it("returns lex diagnostics before validation", async () => {
    const result = await compileAndValidate(`
fn demo.bad() -> int:
  return $
`);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          phase: "lex",
          code: "lex.unexpected-character",
        }),
      ]),
    );
  });

  it("returns parse diagnostics before validation", async () => {
    const result = await compileAndValidate(`
fn demo.bad( -> int:
`);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          phase: "parse",
          code: "parse.unexpected-token",
        }),
      ]),
    );
  });

  it("returns validation warnings when the PG validator is unavailable", async () => {
    vi.spyOn(pgParser, "loadModule").mockRejectedValueOnce(new Error("validator offline"));

    const result = await validateCompiledBundle(
      makeValidationBundle({
        sql: "CREATE OR REPLACE FUNCTION demo.ok() RETURNS void LANGUAGE plpgsql AS $$ BEGIN RETURN; END; $$;",
        functionCount: 1,
      }),
    );

    expect(result.errors).toHaveLength(0);
    expect(result.warnings).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "validate.validator-unavailable",
          functionName: "validator",
          message: "PG validator unavailable: validator offline",
        }),
      ]),
    );
  });

  it("falls back to a synthetic validation block when only SQL is available", async () => {
    vi.spyOn(pgParser, "loadModule").mockResolvedValueOnce(undefined);
    vi.spyOn(pgParser, "parsePlPgSQLSync").mockImplementationOnce(() => {
      throw new Error('syntax error at or near "broken"');
    });

    const result = await validateCompiledBundle(
      makeValidationBundle({
        sql: "CREATE OR REPLACE FUNCTION demo.bad() RETURNS void LANGUAGE plpgsql AS $$ BEGIN broken; END; $$;",
        functionCount: 1,
      }),
    );

    expect(result.warnings).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "validate.pg-parse-error",
          functionName: "unknown",
          line: 0,
          col: 0,
        }),
      ]),
    );
  });

  it("maps PG validation warnings to the best segment on the generated line", async () => {
    vi.spyOn(pgParser, "loadModule").mockResolvedValueOnce(undefined);
    vi.spyOn(pgParser, "parsePlPgSQLSync").mockImplementationOnce(() => {
      throw new Error('syntax error at or near "supplier_id" line 3');
    });

    const result = await validateCompiledBundle(
      makeValidationBundle({ sql: "ignored", functionCount: 1 }, [
        {
          sql: "ignored",
          functionName: "demo.bad",
          loc: pointLoc(2, 2),
          sourceMap: {
            lines: [
              { generatedLine: 1, text: "CREATE FUNCTION ...", loc: pointLoc(1, 0), segments: [] },
              {
                generatedLine: 3,
                text: "PERFORM supplier_id;",
                loc: pointLoc(10, 2),
                segments: [{ startCol: 8, endCol: 19, loc: pointLoc(10, 10), text: "supplier_id" }],
              },
            ],
          },
        },
      ]),
    );

    expect(result.warnings).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "validate.pg-parse-error",
          functionName: "demo.bad",
          line: 10,
          col: 10,
        }),
      ]),
    );
  });

  it("maps PG validation warnings by token when no generated line is present", async () => {
    vi.spyOn(pgParser, "loadModule").mockResolvedValueOnce(undefined);
    vi.spyOn(pgParser, "parsePlPgSQLSync").mockImplementationOnce(() => {
      throw new Error('syntax error at or near "jsonb_build_object"');
    });

    const result = await validateCompiledBundle(
      makeValidationBundle({ sql: "ignored", functionCount: 1 }, [
        {
          sql: "ignored",
          functionName: "demo.json",
          loc: pointLoc(3, 2),
          sourceMap: {
            lines: [
              {
                generatedLine: 7,
                text: "RETURN jsonb_build_object('id', 1);",
                loc: pointLoc(30, 2),
                segments: [{ startCol: 9, endCol: 26, loc: pointLoc(30, 9), text: "jsonb_build_object" }],
              },
            ],
          },
        },
      ]),
    );

    expect(result.warnings).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "validate.pg-parse-error",
          functionName: "demo.json",
          line: 30,
          col: 9,
        }),
      ]),
    );
  });

  it("maps end-of-input PG warnings to the last meaningful source segment", async () => {
    vi.spyOn(pgParser, "loadModule").mockResolvedValueOnce(undefined);
    vi.spyOn(pgParser, "parsePlPgSQLSync").mockImplementationOnce(() => {
      throw new Error("syntax error at end of input");
    });

    const result = await validateCompiledBundle(
      makeValidationBundle({ sql: "ignored", functionCount: 1 }, [
        {
          sql: "ignored",
          functionName: "demo.eof",
          loc: pointLoc(4, 2),
          sourceMap: {
            lines: [
              { generatedLine: 1, text: "BEGIN", loc: pointLoc(40, 2), segments: [] },
              {
                generatedLine: 2,
                text: "RETURN some_call(",
                loc: pointLoc(41, 2),
                segments: [{ startCol: 8, endCol: 17, loc: pointLoc(41, 9), text: "some_call" }],
              },
            ],
          },
        },
      ]),
    );

    expect(result.warnings).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "validate.pg-parse-error",
          functionName: "demo.eof",
          line: 41,
          col: 9,
        }),
      ]),
    );
  });

  it("errors on unknown identifiers", () => {
    const source = `
fn demo.bad() -> text:
  return missing_value
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0]).toMatchObject({
      phase: "semantic",
      code: "semantic.unknown-identifier",
    });
    expect(result.errors[0]?.hint).toContain("Declare the variable first");
    expect(result.errors[0]?.message).toContain("unknown identifier 'missing_value'");
  });

  it("errors on parameter reassignment", () => {
    const source = `
fn demo.bad(p_id int) -> int:
  p_id := 42
  return p_id
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0]?.phase).toBe("semantic");
    expect(result.errors[0]?.message).toContain("cannot assign to parameter 'p_id'");
  });

  it("errors when a local variable shadows an import alias", () => {
    const source = `
import jsonb_build_object as obj

fn demo.bad() -> jsonb:
  obj := 1
  return obj
`;
    const result = compile(source);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "semantic.shadowed-import-alias",
          message: "demo.bad: local name 'obj' shadows import alias 'obj'",
        }),
      ]),
    );
  });

  it("warns on unused import aliases", () => {
    const source = `
import jsonb_build_object as obj

fn demo.ok() -> int:
  return 1
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.warnings).toHaveLength(1);
    expect(result.warnings[0]).toMatchObject({
      functionName: "module",
      line: 2,
      col: 0,
    });
    expect(result.warnings[0]?.message).toContain("unused import alias 'obj'");
  });

  it("warns when referenced i18n keys are missing", () => {
    const source = `
module demo
depends pgv

entity demo.task:
  fields:
    title text required

  states draft -> active:
    activate(draft -> active)

  view:
    standard:
      fields: [title]
      stats:
        {key: task_count, label: demo.stat_task_count}
    form:
      'demo.section_task':
        {key: title, type: text, label: demo.field_title, required: true}

  actions:
    delete: {label: demo.action_delete, confirm: demo.confirm_delete}
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.warnings).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "semantic.missing-i18n-translation",
          message: "missing i18n translation 'demo.entity_task' for lang 'fr'",
        }),
        expect.objectContaining({
          code: "semantic.missing-i18n-translation",
          message: "missing i18n translation 'demo.stat_task_count' for lang 'fr'",
        }),
        expect.objectContaining({
          code: "semantic.missing-i18n-translation",
          message: "missing i18n translation 'demo.section_task' for lang 'fr'",
        }),
        expect.objectContaining({
          code: "semantic.missing-i18n-translation",
          message: "missing i18n translation 'demo.field_title' for lang 'fr'",
        }),
        expect.objectContaining({
          code: "semantic.missing-i18n-translation",
          message: "missing i18n translation 'demo.action_delete' for lang 'fr'",
        }),
        expect.objectContaining({
          code: "semantic.missing-i18n-translation",
          message: "missing i18n translation 'demo.confirm_delete' for lang 'fr'",
        }),
        expect.objectContaining({
          code: "semantic.missing-i18n-translation",
          message: "missing i18n translation 'demo.action_activate' for lang 'fr'",
        }),
      ]),
    );
  });

  it("emits structured view field objects from template sections", () => {
    const source = `
module demo
depends pgv

entity demo.task:
  fields:
    title text required
    status text

  view:
    compact: [{key: title, label: demo.field_title}]
    standard:
      fields: [title, {key: status, type: status, label: demo.field_status}]
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("'compact'");
    expect(result.sql).toContain("'fields'");
    expect(result.sql).toContain("'key', 'title'");
    expect(result.sql).toContain("'label', 'demo.field_title'");
    expect(result.sql).toContain("'type', 'status'");
    expect(result.warnings).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "semantic.missing-i18n-translation",
          message: "missing i18n translation 'demo.field_title' for lang 'fr'",
        }),
        expect.objectContaining({
          code: "semantic.missing-i18n-translation",
          message: "missing i18n translation 'demo.field_status' for lang 'fr'",
        }),
      ]),
    );
  });

  it("emits stat variants in view template output", () => {
    const source = `
module demo
depends pgv

entity demo.task:
  fields:
    title text required

  view:
    compact: [title]
    standard:
      fields: [title]
      stats:
        {key: overdue_count, label: demo.stat_overdue_count, variant: warning}
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("'variant', 'warning'");
  });

  it("fails validation when compiled view payload violates the canonical SDUI schema", () => {
    const source = `
module demo
depends pgv

entity demo.task:
  fields:
    title text required

  view:
    compact: [title]
    form:
      'Section':
        {key: title, type: text, label: 'Title'}
`;
    const result = compile(source);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          phase: "validate",
          code: "validate.invalid-view-payload",
        }),
      ]),
    );
    expect(result.errors.some((error) => error.message.includes("view.template.form.sections[0].label"))).toBe(true);
  });

  it("compiles select with static options resolved via function call", () => {
    const source = `
module demo

entity demo.item:
  fields:
    status text required

  view:
    form:
      'demo.section':
        {key: status, type: select, label: demo.field_status, required: true, options: demo.status_options}
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("'options'");
    // options string should emit a function call, not a string literal
    expect(result.sql).toContain("demo.status_options()");
    expect(result.sql).not.toContain("'demo.status_options'");
  });

  it("compiles select with search and RPC options object", () => {
    const source = `
module demo

entity demo.item:
  fields:
    client_id int?

  view:
    form:
      'demo.section':
        {key: client_id, type: select, label: demo.field_client, search: true, options: {source: 'crm://client', display: name}}
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("'search'");
    expect(result.sql).toContain("'options'");
    expect(result.sql).toContain("'source'");
    expect(result.sql).toContain("'crm://client'");
    expect(result.sql).toContain("'display'");
    expect(result.sql).toContain("'name'");
  });

  it("errors on combobox type (use select with search instead)", () => {
    const source = `
module demo

entity demo.item:
  fields:
    client_id int?

  view:
    form:
      'demo.section':
        {key: client_id, type: combobox, label: demo.field_client}
`;
    const result = compile(source);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "parse.invalid-form-field-type",
        }),
      ]),
    );
  });

  it("errors on unknown form field property", () => {
    const source = `
module demo

entity demo.item:
  fields:
    name text required

  view:
    form:
      'demo.section':
        {key: name, type: text, label: demo.field_name, bogus: foo}
`;
    const result = compile(source);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "parse.invalid-form-field-property",
        }),
      ]),
    );
  });

  it("accepts select with canonical search property", () => {
    const source = `
module demo

entity demo.item:
  fields:
    client_id int?

  view:
    form:
      'demo.section':
        {key: client_id, type: select, label: demo.field_client, search: true, source: 'crm://client', display: name}
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("'search'");
    expect(result.sql).toContain("'source'");
    expect(result.sql).toContain("'display'");
  });

  it("errors on form field missing required key", () => {
    const source = `
module demo

entity demo.item:
  fields:
    name text required

  view:
    form:
      'demo.section':
        {type: text, label: demo.field_name}
`;
    const result = compile(source);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "parse.invalid-form-field",
        }),
      ]),
    );
  });

  it("errors on invalid action variant from SDUI contract", () => {
    const source = `
module demo

entity demo.item:
  fields:
    name text required

  actions:
    archive: {label: demo.action_archive, variant: accent}
`;
    const result = compile(source);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "parse.invalid-action-variant",
          phase: "parse",
        }),
      ]),
    );
  });

  it("errors when emit is used outside entity change hooks", () => {
    const source = `
fn demo.bad() -> void:
  emit received(1)
`;
    const result = compile(source);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "semantic.emit-outside-entity-change-hook",
          message: "demo.bad: emit is only allowed inside entity change hooks",
        }),
      ]),
    );
  });

  it("errors when emitted event argument count does not match the contract", () => {
    const source = `
entity demo.task:
  fields:
    title text required

  event renamed(task_id int, title text)

  on update(new, old):
    emit renamed(new.id)
`;
    const result = compile(source);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "semantic.emit-argument-count",
          message: "entity demo.task update: event 'renamed' expects 2 argument(s)",
        }),
      ]),
    );
  });

  it("errors on duplicate entity events and change hooks", () => {
    const source = `
entity demo.task:
  fields:
    title text required

  event renamed(task_id int)
  event renamed(task_id int)

  on update(new, old):
    emit renamed(new.id)

  on update(newer, older):
    emit renamed(newer.id)
`;
    const result = compile(source);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "semantic.duplicate-entity-event",
          message: "entity demo.task: duplicate event 'renamed'",
        }),
        expect.objectContaining({
          code: "semantic.duplicate-entity-change-hook",
          message: "entity demo.task: duplicate change hook 'update'",
        }),
      ]),
    );
  });

  it("maps semantic errors inside interpolation to source location", () => {
    const source = `
fn demo.bad(name text) -> text:
  return "Hello #{missing_value}"
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0]).toMatchObject({
      phase: "semantic",
      line: 3,
      col: 18,
    });
    expect(result.errors[0]?.message).toContain("unknown identifier 'missing_value'");
  });

  it("parses full expressions inside interpolation", () => {
    const source = `
import jsonb_build_object as obj

fn demo.message(name text, row jsonb) -> text:
  return "Hello #{upper(name)} / #{(row->>'id')::int} / #{obj('ok', true)}"
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.warnings).toHaveLength(0);
    expect(result.sql).toContain(
      "RETURN 'Hello ' || upper(name) || ' / ' || (row->>'id')::int || ' / ' || jsonb_build_object('ok', true);",
    );
  });

  it("tracks interpolation fragments in generated source maps", () => {
    const source = `
fn demo.msg(name text, row jsonb) -> text:
  return "Hello #{upper(name)} / #{(row->>'id')::int}"
`;
    const mod = parse(tokenize(source));
    const fn = mod.functions[0];
    expect(fn).toBeDefined();
    if (!fn) throw new Error("expected generated function");
    const generated = generateWithSourceMap(fn);
    const returnLine = generated.sourceMap.lines.find((line) => line.text.includes("RETURN 'Hello '"));

    expect(returnLine).toBeDefined();
    expect(returnLine?.loc).toEqual(expect.objectContaining({ line: 3, col: 2, endLine: 3 }));
    expect(returnLine?.segments).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ text: "upper(name)", loc: expect.objectContaining({ line: 3, col: 18 }) }),
        expect.objectContaining({ text: "(row->>'id')::int", loc: expect.objectContaining({ line: 3, col: 35 }) }),
      ]),
    );
  });

  it("handles nested braces and quoted braces inside interpolation", () => {
    const source = `
fn demo.payload(name text, id int) -> text:
  return "#{coalesce(name, '}')} #{ {id, label: coalesce(name, '}')} }"
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("coalesce(name, '}')");
    expect(result.sql).toContain("jsonb_build_object('id', id, 'label', coalesce(name, '}'))");
  });

  it("reports unterminated interpolation as a parse error", () => {
    const source = `
fn demo.bad(name text) -> text:
  return "Hello #{name"
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0]?.phase).toBe("parse");
    expect(result.errors[0]?.message).toContain("unterminated interpolation");
  });

  it("reports empty interpolation as a parse error", () => {
    const source = `
fn demo.bad() -> text:
  return "Hello #{}"
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0]).toMatchObject({
      phase: "parse",
      line: 3,
      col: 18,
    });
    expect(result.errors[0]?.message).toContain("empty interpolation");
  });

  it("warns on obvious assignment type mismatches", () => {
    const source = `
fn demo.bad() -> void:
  value := 1
  value := 'oops'
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.warnings).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "type.assignment-mismatch",
          functionName: "demo.bad",
          line: 4,
          col: 2,
        }),
      ]),
    );
  });

  it("warns when conditions are not boolean", () => {
    const source = `
fn demo.bad() -> int:
  if 42:
    return 1
  return 0
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.warnings).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "type.non-boolean-condition",
          functionName: "demo.bad",
          line: 3,
          col: 2,
        }),
      ]),
    );
  });

  it("rejects legacy return query/execute modes", () => {
    const source = `
fn demo.query(name text) -> setof text:
  return query select name
`;
    const result = compile(source);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          phase: "parse",
          code: "parse.legacy-return-mode",
        }),
      ]),
    );
  });

  it("compiles IS NULL and IS NOT NULL expressions", () => {
    const source = `
fn demo.check(p_val text) -> text:
  if p_val is null:
    return 'null'
  if p_val is not null:
    return 'present'
  return 'unknown'
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("IF p_val IS NULL THEN");
    expect(result.sql).toContain("IF p_val IS NOT NULL THEN");
  });

  it("compiles try/catch to BEGIN/EXCEPTION WHEN OTHERS", () => {
    const source = `
fn demo.safe(p_id int) -> boolean:
  ok := false
  try:
    demo.risky(p_id)
    ok := true
  catch:
    ok := false
  return ok
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.sql).toContain("BEGIN");
    expect(result.sql).toContain("PERFORM demo.risky(p_id);");
    expect(result.sql).toContain("EXCEPTION WHEN OTHERS THEN");
    expect(result.sql).toContain("END;");
  });

  it("compiles try/catch in test blocks", () => {
    const source = `
test "catches error":
  ok := false
  try:
    demo.will_fail()
  catch:
    ok := true
  assert ok = true
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("BEGIN");
    expect(result.testSql).toContain("EXCEPTION WHEN OTHERS THEN");
    expect(result.testSql).toContain("END;");
    expect(result.testSql).toContain("RETURN NEXT is(");
  });

  it("infers test schema from qualified calls inside nested control flow", () => {
    const source = `
test "nested schema inference":
  if true:
    for item in [1]:
      try:
        crm.client_read(item)
      catch:
        fallback := 1
  assert true
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("crm_ut.test_nested_schema_inference");
  });

  it("infers test schema from unary/grouped assert expressions", () => {
    const source = `
test "grouped unary schema inference":
  assert not (crm.client_exists(1))
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("crm_ut.test_grouped_unary_schema_inference");
  });

  it("infers test schema from return statements", () => {
    const source = `
test "return schema inference":
  return crm.client_read(1)
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("crm_ut.test_return_schema_inference");
  });

  it("errors when i18n is declared without a module name", () => {
    const mod = parse(tokenize(""));
    mod.depends.push({ name: "pgv", loc: pointLoc(1, 0) });
    mod.i18n.push({
      lang: "fr",
      loc: pointLoc(1, 0),
      entries: [{ key: "demo.title", value: "Titre", loc: pointLoc(2, 2) }],
    });
    const result = compileModule(mod);
    expect(result.errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: "codegen.i18n-missing-module",
          message: "i18n blocks require a module declaration",
        }),
      ]),
    );
  });

  it("compiles IS NULL in test assert to pgTAP is()", () => {
    const source = `
test "null assert":
  r := demo.get_value()
  assert r is null
  assert r is not null
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("RETURN NEXT is(v_r, NULL,");
    expect(result.testSql).toContain("RETURN NEXT ok(v_r IS NOT NULL,");
  });
});
