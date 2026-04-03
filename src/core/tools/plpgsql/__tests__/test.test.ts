import { describe, expect, it } from "vitest";
import type { DbClient, QueryResult } from "../../../connection.js";
import { runTests } from "../test.js";

class FakeClient implements DbClient {
  async query<T = unknown>(sql: string, params?: unknown[]): Promise<QueryResult<T>> {
    if (sql.includes("FROM pg_namespace WHERE nspname = $1")) {
      return { rows: [{ exists: true }] as T[], rowCount: 1 };
    }
    if (sql.includes("FROM pg_extension WHERE extname = 'pgtap'")) {
      return { rows: [{ exists: true }] as T[], rowCount: 1 };
    }
    if (sql.includes("SELECT now() != statement_timestamp() AS in_tx")) {
      return { rows: [{ in_tx: false }] as T[], rowCount: 1 };
    }
    if (
      sql.startsWith("BEGIN") ||
      sql.startsWith("ROLLBACK") ||
      sql.startsWith("SET LOCAL search_path") ||
      sql.startsWith("SET LOCAL app.tenant_id") ||
      sql.startsWith("SET LOCAL app.permissions")
    ) {
      return { rows: [], rowCount: 0 };
    }
    if (sql.includes("FROM pg_proc p") && sql.includes("WHERE n.nspname = $1") && !sql.includes("p.proname ~ $2")) {
      expect(params).toEqual(["demo"]);
      return {
        rows: [
          { proname: "note_create" },
          { proname: "note_read" },
          { proname: "note_update" },
          { proname: "note_delete" },
        ] as T[],
        rowCount: 4,
      };
    }
    if (sql.includes("WHERE n.nspname = $1 AND p.proname ~ $2")) {
      expect(params).toEqual(["demo_ut", "^test_"]);
      return { rows: [{ proname: "test_health" }] as T[], rowCount: 1 };
    }
    if (sql.includes("SELECT * FROM runtests(")) {
      return {
        rows: [
          { runtests: "# Subtest: demo_ut.test_health()" },
          { runtests: "not ok 1 - demo_ut.test_health" },
          { runtests: '# Failed test 1: "demo_ut.test_health"' },
          { runtests: "1..1" },
        ] as T[],
        rowCount: 4,
      };
    }

    throw new Error(`Unexpected query: ${sql}`);
  }
}

describe("plpgsql test runner", () => {
  it("parses top-level TAP failures returned by runtests() and injects default test context", async () => {
    const report = await runTests(new FakeClient(), "demo_ut");

    expect(report).not.toBeNull();
    expect(report?.passed).toBe(0);
    expect(report?.failed).toBe(1);
    expect(report?.total).toBe(1);
    expect(report?.results[0]?.description).toBe("demo_ut.test_health");
  });
});
