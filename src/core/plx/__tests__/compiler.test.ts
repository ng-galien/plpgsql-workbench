import { describe, expect, it } from "vitest";
import { generateWithSourceMap } from "../codegen.js";
import { compile, compileAndValidate } from "../compiler.js";
import { tokenize } from "../lexer.js";
import { parse } from "../parser.js";

describe("PLX test compilation", () => {
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
    expect(result.sql).toContain("jsonb_populate_record(NULL::demo.task, p_input)");
    expect(result.sql).toContain("jsonb_populate_record(v_current, p_input)");
  });

  it("supports columns + payload entities with hybrid storage", () => {
    const source = `
entity demo.task:
  columns:
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

  it("generates foreign key constraints for ref(...) columns", () => {
    const source = `
entity demo.note:
  fields:
    title text required

entity demo.task:
  columns:
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
