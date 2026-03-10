import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { PlUri } from "../../uri.js";

// --- Shared service (registered in container, injected into set + coverage) ---

export interface TestReport {
  passed: number;
  failed: number;
  total: number;
  results: TapResult[];
}

interface TapResult {
  ok: boolean;
  description: string;
  have?: string;
  want?: string;
}

function parseTap(rows: { runtests: string }[]): TestReport {
  const results: TapResult[] = [];
  let current: TapResult | null = null;

  const lines: string[] = [];
  for (const row of rows) lines.push(...row.runtests.split("\n"));

  for (const line of lines) {
    const tapMatch = line.match(/^\s+(not )?ok \d+ - (.+)$/);
    if (tapMatch) {
      if (current) results.push(current);
      current = { ok: !tapMatch[1], description: tapMatch[2] };
      continue;
    }

    if (current && !current.ok) {
      const haveMatch = line.match(/#\s+have:\s*(.+)/);
      if (haveMatch) { current.have = haveMatch[1]; continue; }
      const wantMatch = line.match(/#\s+want:\s*(.+)/);
      if (wantMatch) { current.want = wantMatch[1]; continue; }
    }
  }
  if (current) results.push(current);

  const passed = results.filter((r) => r.ok).length;
  const failed = results.filter((r) => !r.ok).length;
  return { passed, failed, total: results.length, results };
}

export function formatTestReport(report: TestReport): string {
  const parts: string[] = [];
  const sym = report.failed > 0 ? "✗" : "✓";
  parts.push(`${sym} ${report.passed} passed, ${report.failed} failed, ${report.total} total`);
  parts.push(`completeness: full`);
  parts.push("");

  for (const r of report.results) {
    if (r.ok) {
      parts.push(`  ✓ ${r.description}`);
    } else {
      parts.push(`  ✗ ${r.description}`);
      if (r.have !== undefined) parts.push(`    have: ${r.have}`);
      if (r.want !== undefined) parts.push(`    want: ${r.want}`);
    }
  }

  return parts.join("\n");
}

export async function runTests(
  client: DbClient,
  testSchema: string,
  pattern?: string,
): Promise<TestReport | null> {
  const { rows: schemaCheck } = await client.query<{ exists: boolean }>(
    `SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = $1) AS exists`,
    [testSchema],
  );
  if (!schemaCheck[0].exists) return null;

  const { rows: extCheck } = await client.query<{ exists: boolean }>(
    `SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pgtap') AS exists`,
  );
  if (!extCheck[0].exists) return null;

  const sourceSchema = testSchema.replace(/_(ut|it)$/, "");

  const filter = pattern ?? `^test_`;
  const ql = (s: string) => `'${s.replace(/'/g, "''")}'`;
  const qi = (s: string) => `"${s.replace(/"/g, '""')}"`;

  // Use SAVEPOINT + SET LOCAL so search_path is automatically restored
  // on RELEASE/ROLLBACK — no state leak on the pooled connection
  await client.query("SAVEPOINT test_run");
  await client.query(`SET LOCAL search_path TO ${qi(testSchema)}, ${qi(sourceSchema)}, public`);
  try {
    const { rows } = await client.query<{ runtests: string }>(
      `SELECT * FROM runtests(${ql(testSchema)}::name, ${ql(filter)}::text)`,
    );
    await client.query("RELEASE SAVEPOINT test_run");
    if (rows.length === 0) return { passed: 0, failed: 0, total: 0, results: [] };
    return parseTap(rows);
  } catch (err: unknown) {
    await client.query("ROLLBACK TO SAVEPOINT test_run").catch(() => {});
    const msg = err instanceof Error ? err.message : String(err);
    return {
      passed: 0, failed: 1, total: 1,
      results: [{ ok: false, description: `test execution error: ${msg}` }],
    };
  }
}

// --- Tool factory ---

export function createTestTool({ withClient, runTests }: {
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
        uri: z.string().optional().describe("URI: plpgsql://schema (all tests) or plpgsql://schema/function/name (one function's tests)"),
        schema: z.string().optional().describe("Test schema. Ex: public_ut, billing_it"),
        pattern: z.string().optional().describe("Regex filter on test names. Ex: ^test_hello$"),
      }),
    },
    handler: async (args, _extra) => {
      const target = args.uri as string | undefined;
      const schema = args.schema as string | undefined;
      const pattern = args.pattern as string | undefined;

      if (!target && !schema) return text("✗ provide target (function URI) or schema (test schema)");

      return withClient(async (client) => {
        let testSchema: string;
        let testPattern: string | undefined = pattern;

        if (target) {
          const parsed = PlUri.parse(target);
          if (!parsed) {
            return text("✗ invalid URI: " + target);
          }
          // URI pointing to a schema (no kind/name) → treat as test schema
          if (!parsed.kind || !parsed.name) {
            testSchema = parsed.schema;
          } else if (parsed.kind === "function") {
            testSchema = `${parsed.schema}_ut`;
            testPattern = `^test_${parsed.name}$`;
          } else {
            return text("✗ target must be a function URI or schema URI");
          }
        } else {
          testSchema = schema!;
        }

        const report = await runTests(client, testSchema, testPattern);
        if (!report) {
          return text(`✗ test schema "${testSchema}" not found or pgTAP not installed`);
        }

        if (report.total === 0) {
          const msg = target
            ? `no test found (expected ${testSchema}.test_${PlUri.parse(target)!.name})`
            : `no tests in ${testSchema}`;
          return text(msg);
        }

        return text(formatTestReport(report));
      });
    },
  };
}
