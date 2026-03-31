import { describe, expect, it } from "vitest";
import { compile } from "../compiler.js";

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
});
