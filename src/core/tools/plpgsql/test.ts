import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { formatReadDocument } from "../../tooling/primitives/read.js";
import { expectPlpgsqlSchemaOrFunctionTarget } from "../../tooling/primitives/target-validation.js";
import {
  formatTapDiagnosticReport,
  parseTapDiagnostics,
  type TapDiagnosticReport,
} from "../../tooling/primitives/test-diagnostics.js";
import {
  closeDeterministicTestSession,
  openDeterministicTestSession,
  rollbackDeterministicTestSession,
} from "../../tooling/primitives/test-session.js";

// --- Shared service (registered in container, injected into set + coverage) ---

export type TestReport = TapDiagnosticReport;

export function formatTestReport(report: TestReport): string {
  return formatTapDiagnosticReport(report);
}

export async function runTests(client: DbClient, testSchema: string, pattern?: string): Promise<TestReport | null> {
  const { rows: schemaCheck } = await client.query<{ exists: boolean }>(
    `SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = $1) AS exists`,
    [testSchema],
  );
  if (!schemaCheck[0]?.exists) return null;

  const { rows: extCheck } = await client.query<{ exists: boolean }>(
    `SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pgtap') AS exists`,
  );
  if (!extCheck[0]?.exists) return null;

  const filter = pattern ?? `^test_`;
  const ql = (s: string) => `'${s.replace(/'/g, "''")}'`;
  const session = await openDeterministicTestSession(client, {
    testSchema,
    extraSchemas: testSchema.endsWith("_it") ? ["pgv_ut", "pgv"] : [],
  });
  try {
    // Check for test functions that exist in src/ but failed to compile (invisible to pgTAP)
    const { rows: srcFiles } = await client.query<{ proname: string }>(
      `SELECT p.proname FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = $1 AND p.proname ~ $2
       ORDER BY p.proname`,
      [testSchema, filter],
    );
    const compiledTests = new Set(srcFiles.map((r) => r.proname));

    const { rows } = await client.query<{ runtests: string }>(
      `SELECT * FROM runtests(${ql(testSchema)}::name, ${ql(filter)}::text)`,
    );
    await closeDeterministicTestSession(client, session);
    if (rows.length === 0 && compiledTests.size === 0) {
      return { passed: 0, failed: 0, total: 0, results: [] };
    }
    const report = rows.length > 0 ? parseTapDiagnostics(rows) : { passed: 0, failed: 0, total: 0, results: [] };

    // Warn about 0 compiled tests when source files likely exist
    if (compiledTests.size === 0 && report.total === 0) {
      report.results.push({
        ok: false,
        description: `⚠ no test functions found in ${testSchema} — functions may have failed to compile. Check pg_get plpgsql://${testSchema} for errors.`,
      });
      report.failed = 1;
      report.total = 1;
    }

    return report;
  } catch (err: unknown) {
    await rollbackDeterministicTestSession(client, session);
    const msg = err instanceof Error ? err.message : String(err);
    return {
      passed: 0,
      failed: 1,
      total: 1,
      results: [{ ok: false, description: `test execution error: ${msg}` }],
    };
  }
}

// --- Tool factory ---

export function createTestTool({
  withClient,
  runTests,
}: {
  withClient: WithClient;
  runTests: (client: DbClient, testSchema: string, pattern?: string) => Promise<TestReport | null>;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_test",
      description:
        "Run pgTAP tests. target: run unit test for a function. schema: run all tests in a test schema.\n" +
        "Convention and examples: pg_get plpgsql://workbench/doc/testing",
      schema: z.object({
        uri: z
          .string()
          .optional()
          .describe("URI: plpgsql://schema (all tests) or plpgsql://schema/function/name (one function's tests)"),
        schema: z.string().optional().describe("Test schema. Ex: public_ut, billing_it"),
        pattern: z.string().optional().describe("Regex filter on test names. Ex: ^test_hello$"),
      }),
    },
    handler: async (args, _extra) => {
      const target = args.uri as string | undefined;
      const schema = args.schema as string | undefined;
      const pattern = args.pattern as string | undefined;

      if (!target && !schema) {
        return text("✗ provide target (function URI) or schema (test schema)");
      }

      return withClient(async (client) => {
        let testSchema: string;
        let testPattern: string | undefined = pattern;

        if (target) {
          const validated = expectPlpgsqlSchemaOrFunctionTarget(target, "pg_test");
          if (!validated.ok) {
            return text(`✗ ${validated.failure.problem}`);
          }
          if (validated.value.kind === "schema") {
            testSchema = validated.value.schema;
          } else {
            testSchema = `${validated.value.schema}_ut`;
            testPattern = `^test_${validated.value.name}$`;
          }
        } else {
          if (!schema) {
            return text("✗ provide target (function URI) or schema (test schema)");
          }
          testSchema = schema;
        }

        const report = await runTests(client, testSchema, testPattern);
        if (!report) {
          return text(`✗ test schema "${testSchema}" not found or pgTAP not installed`);
        }

        if (report.total === 0) {
          const validated = target ? expectPlpgsqlSchemaOrFunctionTarget(target, "pg_test") : null;
          const msg = target
            ? `no test found (expected ${testSchema}.test_${validated?.ok && validated.value.kind === "function" ? validated.value.name : "unknown"})`
            : `no tests in ${testSchema}`;
          return text(msg);
        }

        return text(
          formatReadDocument({
            uri: target ? `plpgsql-test://${testSchema}` : undefined,
            completeness: "full",
            body: formatTestReport(report),
          }),
        );
      });
    },
  };
}
