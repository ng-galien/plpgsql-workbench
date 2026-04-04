import { describe, expect, it, vi } from "vitest";
import {
  diffAppliedArtifacts,
  ensureAppliedArtifactTable,
  mapAppliedArtifactRows,
  readAppliedArtifactStates,
  upsertAppliedArtifactState,
} from "../applied-artifacts.js";
import { createToolFailure, formatToolFailure, toolFailureFromError } from "../failure.js";
import { notifyPostgrestSchemaReload } from "../postgrest.js";
import { formatReadDocument, formatReadSections } from "../read.js";
import { resolvePlpgsqlTarget } from "../target-resolution.js";
import {
  expectPlpgsqlFunctionTarget,
  expectPlpgsqlSchemaOrFunctionTarget,
  expectPlpgsqlSchemaTarget,
} from "../target-validation.js";
import { formatTapDiagnosticReport, parseTapDiagnostics } from "../test-diagnostics.js";
import {
  closeDeterministicTestSession,
  inferCrudStylePermissions,
  openDeterministicTestSession,
  rollbackDeterministicTestSession,
} from "../test-session.js";
import { withSavepoint, withTransaction } from "../transaction.js";

describe("tooling primitives", () => {
  function recordedSql(query: ReturnType<typeof vi.fn>): string[] {
    return query.mock.calls.map((call) => String(call[0]));
  }

  it("formats tool failures consistently", () => {
    const failure = createToolFailure("boom", "runtime_apply", { stage: "apply", fixHint: "check the SQL order" });
    expect(formatToolFailure(failure)).toBe(
      "problem: boom\nwhere: runtime_apply\nfailure_stage: apply\nfix_hint: check the SQL order",
    );
    expect(toolFailureFromError(new Error("bad target"), "runtime_status")).toEqual({
      problem: "bad target",
      where: "runtime_status",
      fixHint: undefined,
      stage: undefined,
    });
  });

  it("diffs and maps applied artifacts generically", () => {
    const artifacts = [
      { key: "sql:src/a.sql", kind: "sql" as const, name: "a", hash: "aaa" },
      { key: "sql:src/b.sql", kind: "sql" as const, name: "b", hash: "bbb" },
    ];
    const applied = mapAppliedArtifactRows([
      {
        artifact_key: "sql:src/a.sql",
        artifact_kind: "sql" as const,
        artifact_name: "a",
        artifact_hash: "aaa",
        artifact_file: "src/a.sql",
        applied_at: "2026-04-04 00:00:00+00",
      },
      {
        artifact_key: "sql:src/old.sql",
        artifact_kind: "sql" as const,
        artifact_name: "old",
        artifact_hash: "zzz",
        artifact_file: "src/old.sql",
        applied_at: "2026-04-03 00:00:00+00",
      },
    ]);

    const diff = diffAppliedArtifacts(artifacts, applied);
    expect(diff.unchanged.map((artifact) => artifact.key)).toEqual(["sql:src/a.sql"]);
    expect(diff.changed.map((artifact) => artifact.key)).toEqual(["sql:src/b.sql"]);
    expect(diff.obsolete.map((artifact) => artifact.key)).toEqual(["sql:src/old.sql"]);
  });

  it("handles applied artifact table primitives", async () => {
    const query = vi.fn(async (sql: string) => {
      if (sql.includes("SELECT artifact_key")) {
        return {
          rows: [
            {
              artifact_key: "ddl:build/sdui.ddl.sql",
              artifact_kind: "ddl",
              artifact_name: "sdui",
              artifact_hash: "abc",
              artifact_file: "build/sdui.ddl.sql",
              applied_at: "2026-04-04 00:00:00+00",
            },
          ],
          rowCount: 1,
        };
      }
      return { rows: [], rowCount: 0 };
    });
    const client = { query } as never;

    await ensureAppliedArtifactTable(client, { table: "applied_runtime_artifact", scopeColumn: "runtime_target" });
    const states = await readAppliedArtifactStates(client, {
      table: "applied_runtime_artifact",
      scopeColumn: "runtime_target",
      scopeValue: "sdui",
    });
    await upsertAppliedArtifactState(
      client,
      { table: "applied_runtime_artifact", scopeColumn: "runtime_target", scopeValue: "sdui" },
      { key: "sql:src/api.sql", kind: "sql", name: "api", hash: "def" },
      "src/api.sql",
    );

    expect(states.available).toBe(true);
    expect(states.states.get("ddl:build/sdui.ddl.sql")?.name).toBe("sdui");
    expect(query).toHaveBeenCalledTimes(4);
  });

  it("treats missing tracking tables as unavailable and reloads postgrest safely", async () => {
    const query = vi
      .fn()
      .mockRejectedValueOnce(Object.assign(new Error("missing"), { code: "42P01" }))
      .mockRejectedValueOnce(new Error("notify failed"));
    const client = { query } as never;

    const result = await readAppliedArtifactStates(client, {
      table: "applied_runtime_artifact",
      scopeColumn: "runtime_target",
      scopeValue: "sdui",
    });
    await notifyPostgrestSchemaReload(client);

    expect(result).toEqual({ available: false, states: new Map() });
  });

  it("wraps work in a transaction and commits on success", async () => {
    const query = vi.fn(async () => ({ rows: [], rowCount: 0 }));
    const client = { query } as never;

    const result = await withTransaction(client, async () => "ok");

    expect(result).toBe("ok");
    expect(recordedSql(query)).toEqual(["BEGIN", "COMMIT"]);
  });

  it("rolls back and rethrows on transaction failure", async () => {
    const query = vi.fn(async () => ({ rows: [], rowCount: 0 }));
    const client = { query } as never;

    await expect(
      withTransaction(client, async () => {
        throw new Error("boom");
      }),
    ).rejects.toThrow("boom");

    expect(recordedSql(query)).toEqual(["BEGIN", "ROLLBACK"]);
  });

  it("uses savepoints and sanitizes savepoint names", async () => {
    const query = vi.fn(async () => ({ rows: [], rowCount: 0 }));
    const client = { query } as never;

    const result = await withSavepoint(client, "plpgsql-check:1", async () => "ok");

    expect(result).toBe("ok");
    expect(recordedSql(query)).toEqual(["SAVEPOINT plpgsql_check_1", "RELEASE SAVEPOINT plpgsql_check_1"]);
  });

  it("rolls back to savepoint and rethrows on failure", async () => {
    const query = vi.fn(async () => ({ rows: [], rowCount: 0 }));
    const client = { query } as never;

    await expect(
      withSavepoint(client, "boundary-check", async () => {
        throw new Error("bad boundary");
      }),
    ).rejects.toThrow("bad boundary");

    expect(recordedSql(query)).toEqual(["SAVEPOINT boundary_check", "ROLLBACK TO SAVEPOINT boundary_check"]);
  });

  it("resolves plpgsql targets into explicit target kinds", () => {
    expect(resolvePlpgsqlTarget("plpgsql://")).toEqual({ kind: "catalog", uri: "plpgsql://" });
    expect(resolvePlpgsqlTarget("plpgsql://workbench/doc")).toEqual({
      kind: "doc_index",
      uri: "plpgsql://workbench/doc",
    });
    expect(resolvePlpgsqlTarget("plpgsql://workbench/doc/testing")).toEqual({
      kind: "doc_topic",
      uri: "plpgsql://workbench/doc/testing",
      topic: "testing",
    });
    expect(resolvePlpgsqlTarget("plpgsql://crm")).toEqual({
      kind: "schema",
      uri: "plpgsql://crm",
      schema: "crm",
    });
    expect(resolvePlpgsqlTarget("plpgsql://crm/function/*")).toEqual({
      kind: "glob",
      uri: "plpgsql://crm/function/*",
      schema: "crm",
      resourceKind: "function",
    });
    expect(resolvePlpgsqlTarget("plpgsql://crm/function/client_read")).toEqual({
      kind: "resource",
      uri: "plpgsql://crm/function/client_read",
      schema: "crm",
      resourceKind: "function",
      name: "client_read",
    });
    expect(resolvePlpgsqlTarget("plpgsql://crm/view/index")).toEqual({
      kind: "invalid",
      uri: "plpgsql://crm/view/index",
      problem: "invalid URI: plpgsql://crm/view/index",
    });
  });

  it("formats read documents and sections consistently", () => {
    expect(
      formatReadDocument({
        uri: "runtime://sdui",
        body: "target: sdui",
        next: ["runtime_apply target:sdui"],
      }),
    ).toBe("uri: runtime://sdui\ncompleteness: full\n\ntarget: sdui\n\nnext:\n  - runtime_apply target:sdui");

    expect(
      formatReadSections(
        [
          { title: "functions (2)", lines: ["  a  plpgsql://crm/function/a", "  b  plpgsql://crm/function/b"] },
          { title: "tables (1)", lines: ["  client  plpgsql://crm/table/client"] },
        ],
        { completeness: "partial", next: ["narrow with schema:crm"] },
      ),
    ).toBe(
      "completeness: partial\n\nfunctions (2):\n  a  plpgsql://crm/function/a\n  b  plpgsql://crm/function/b\n\ntables (1):\n  client  plpgsql://crm/table/client\n\nnext:\n  - narrow with schema:crm",
    );
  });

  it("validates plpgsql schema and function targets with precise fix hints", () => {
    expect(expectPlpgsqlSchemaTarget("plpgsql://crm", "pg_func_load")).toEqual({
      ok: true,
      value: { uri: "plpgsql://crm", schema: "crm" },
    });
    expect(expectPlpgsqlFunctionTarget("plpgsql://crm/function/client_read", "pg_func_del")).toEqual({
      ok: true,
      value: { uri: "plpgsql://crm/function/client_read", schema: "crm", name: "client_read" },
    });
    expect(expectPlpgsqlSchemaOrFunctionTarget("plpgsql://crm", "pg_coverage")).toEqual({
      ok: true,
      value: { kind: "schema", uri: "plpgsql://crm", schema: "crm" },
    });
    expect(expectPlpgsqlSchemaOrFunctionTarget("plpgsql://crm/function/client_read", "pg_coverage")).toEqual({
      ok: true,
      value: { kind: "function", uri: "plpgsql://crm/function/client_read", schema: "crm", name: "client_read" },
    });
    expect(expectPlpgsqlSchemaTarget("plpgsql://crm/function/client_read", "pg_func_load")).toEqual({
      ok: false,
      failure: {
        problem: "invalid target: plpgsql://crm/function/client_read",
        where: "pg_func_load",
        fixHint: "use plpgsql://schema",
        stage: undefined,
      },
    });
    expect(expectPlpgsqlFunctionTarget("plpgsql://crm", "pg_func_del")).toEqual({
      ok: false,
      failure: {
        problem: "invalid target: plpgsql://crm",
        where: "pg_func_del",
        fixHint: "use plpgsql://schema/function/name",
        stage: undefined,
      },
    });
  });

  it("prepares deterministic test sessions and infers CRUD-style permissions", async () => {
    const query = vi.fn(async (sql: string) => {
      if (sql.includes("statement_timestamp()")) return { rows: [{ in_tx: false }], rowCount: 1 };
      if (sql.includes("SELECT p.proname")) {
        return {
          rows: [
            { proname: "task_create" },
            { proname: "task_update" },
            { proname: "task_list" },
            { proname: "_internal" },
            { proname: "on_task_change" },
          ],
          rowCount: 5,
        };
      }
      return { rows: [], rowCount: 0 };
    });
    const client = { query } as never;

    const permissions = await inferCrudStylePermissions(client, "crm");
    const state = await openDeterministicTestSession(client, {
      testSchema: "crm_ut",
      extraSchemas: ["helpers_ut"],
    });
    await closeDeterministicTestSession(client, state);

    expect(permissions).toEqual(["crm.task.create", "crm.task.modify", "crm.task.read"]);
    expect(state.sourceSchema).toBe("crm");
    expect(state.permissions).toEqual(["crm.task.create", "crm.task.modify", "crm.task.read"]);
    expect(query.mock.calls.map((call) => String(call[0]))).toContain(
      `SELECT p.proname
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = $1
      ORDER BY p.proname`,
    );
    expect(query.mock.calls.slice(1).map((call) => String(call[0]))).toEqual([
      "SELECT now() != statement_timestamp() AS in_tx",
      "BEGIN",
      'SET LOCAL search_path TO "crm_ut", "crm", "helpers_ut", "public"',
      "SET LOCAL app.tenant_id = 'test'",
      `SELECT p.proname
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = $1
      ORDER BY p.proname`,
      "SET LOCAL app.permissions = 'crm.task.create,crm.task.modify,crm.task.read'",
      "ROLLBACK",
    ]);
  });

  it("rolls back deterministic test sessions to savepoint when already in transaction", async () => {
    const query = vi.fn(async (sql: string) => {
      if (sql.includes("statement_timestamp()")) return { rows: [{ in_tx: true }], rowCount: 1 };
      if (sql.includes("SELECT p.proname")) return { rows: [], rowCount: 0 };
      return { rows: [], rowCount: 0 };
    });
    const client = { query } as never;

    const state = await openDeterministicTestSession(client, {
      testSchema: "crm_it",
      extraSchemas: ["pgv_ut", "pgv"],
      tenantId: "it",
    });
    await rollbackDeterministicTestSession(client, state);

    expect(query.mock.calls.map((call) => String(call[0]))).toEqual([
      "SELECT now() != statement_timestamp() AS in_tx",
      "SAVEPOINT test_run",
      'SET LOCAL search_path TO "crm_it", "crm", "pgv_ut", "pgv", "public"',
      "SET LOCAL app.tenant_id = 'it'",
      `SELECT p.proname
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = $1
      ORDER BY p.proname`,
      "ROLLBACK TO SAVEPOINT test_run",
    ]);
  });

  it("parses and formats TAP diagnostics", () => {
    const report = parseTapDiagnostics([
      {
        runtests: [
          "ok 1 - test_ok",
          "not ok 2 - test_failure",
          "# have: actual",
          "# want: expected",
          "not ok 3 - test_error",
          "# Test died: P0001: boom",
          "# CONTEXT:",
          "#      PL/pgSQL function crm.test_error() line 4 at RAISE",
        ].join("\n"),
      },
    ]);

    expect(report).toEqual({
      passed: 1,
      failed: 2,
      total: 3,
      results: [
        { ok: true, description: "test_ok" },
        { ok: false, description: "test_failure", have: "actual", want: "expected" },
        {
          ok: false,
          description: "test_error",
          sqlstate: "P0001",
          error: "boom",
          context: ["PL/pgSQL function crm.test_error() line 4 at RAISE"],
        },
      ],
    });
    expect(formatTapDiagnosticReport(report)).toBe(
      [
        "✗ 1 passed, 2 failed, 3 total",
        "completeness: full",
        "",
        "  ✓ test_ok",
        "  ✗ test_failure",
        "    have: actual",
        "    want: expected",
        "  ✗ test_error",
        "    error: P0001: boom",
        "    context:",
        "      PL/pgSQL function crm.test_error() line 4 at RAISE",
      ].join("\n"),
    );
  });
});
