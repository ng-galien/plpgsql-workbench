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

  it("infers schema from first qualified call", () => {
    const source = `
test "schema inference":
  r := crm.client_read(1)
  assert r->>'name' = 'Test'
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(0);
    expect(result.testSql).toContain("crm_ut.test_schema_inference");
  });

  it("errors when no qualified call found", () => {
    const source = `
test "no schema":
  x := 1
  assert x = 1
`;
    const result = compile(source);
    expect(result.errors.length).toBeGreaterThan(0);
    expect(result.errors[0]!.message).toContain("cannot infer schema");
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
    expect(result.warnings).toHaveLength(1);
    expect(result.warnings[0]).toMatchObject({
      functionName: "demo.bad",
      line: 3,
      col: 2,
    });
    expect(result.warnings[0]!.message).toContain("PG parse:");
  });

  it("errors on unknown identifiers", () => {
    const source = `
fn demo.bad() -> text:
  return missing_value
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0]!.phase).toBe("semantic");
    expect(result.errors[0]!.message).toContain("unknown identifier 'missing_value'");
  });

  it("errors on parameter reassignment", () => {
    const source = `
fn demo.bad(p_id int) -> int:
  p_id := 42
  return p_id
`;
    const result = compile(source);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0]!.phase).toBe("semantic");
    expect(result.errors[0]!.message).toContain("cannot assign to parameter 'p_id'");
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
    expect(result.warnings[0]!.message).toContain("unused import alias 'obj'");
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
    expect(result.errors[0]!.message).toContain("unknown identifier 'missing_value'");
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
    const generated = generateWithSourceMap(mod.functions[0]!);
    const returnLine = generated.sourceMap.lines.find((line) => line.text.includes("RETURN 'Hello '"));

    expect(returnLine).toBeDefined();
    expect(returnLine!.loc).toEqual({ line: 3, col: 2 });
    expect(returnLine!.segments).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ text: "upper(name)", loc: { line: 3, col: 18 } }),
        expect.objectContaining({ text: "(row->>'id')::int", loc: { line: 3, col: 35 } }),
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
    expect(result.errors[0]!.phase).toBe("parse");
    expect(result.errors[0]!.message).toContain("unterminated interpolation");
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
    expect(result.errors[0]!.message).toContain("empty interpolation");
  });
});
