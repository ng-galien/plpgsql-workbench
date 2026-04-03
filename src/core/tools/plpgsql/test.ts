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
  sqlstate?: string;
  error?: string;
  context?: string[];
}

function parseTap(rows: { runtests: string }[]): TestReport {
  const results: TapResult[] = [];
  let current: TapResult | null = null;
  let pendingFailure: Pick<TapResult, "sqlstate" | "error" | "context"> | null = null;

  const lines: string[] = [];
  for (const row of rows) lines.push(...row.runtests.split("\n"));

  for (const line of lines) {
    const diedMatch = line.match(/#\s+Test died:\s+([A-Z0-9]+):\s+(.+)/);
    if (diedMatch) {
      pendingFailure = {
        sqlstate: diedMatch[1],
        error: diedMatch[2],
        context: [],
      };
      continue;
    }
    const contextHeader = line.match(/#\s+CONTEXT:\s*$/);
    if (contextHeader && pendingFailure) {
      pendingFailure.context ??= [];
      continue;
    }
    const contextLine = line.match(/#\s{6,}(.+)/);
    if (contextLine && pendingFailure?.context) {
      const contextEntry = contextLine[1];
      if (contextEntry) pendingFailure.context.push(contextEntry);
      continue;
    }

    const tapMatch = line.match(/^\s*(not )?ok \d+ - (.+)$/);
    if (tapMatch) {
      if (current) results.push(current);
      const description = tapMatch[2];
      if (!description) continue;
      current = { ok: !tapMatch[1], description, ...pendingFailure };
      pendingFailure = null;
      continue;
    }

    if (current && !current.ok) {
      const haveMatch = line.match(/#\s+have:\s*(.+)/);
      if (haveMatch) {
        current.have = haveMatch[1];
        continue;
      }
      const wantMatch = line.match(/#\s+want:\s*(.+)/);
      if (wantMatch) {
        current.want = wantMatch[1];
      }
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
      if (r.sqlstate || r.error) {
        parts.push(`    error: ${[r.sqlstate, r.error].filter(Boolean).join(": ")}`);
      }
      if (r.context && r.context.length > 0) {
        parts.push("    context:");
        for (const line of r.context) parts.push(`      ${line}`);
      }
      if (r.have !== undefined) parts.push(`    have: ${r.have}`);
      if (r.want !== undefined) parts.push(`    want: ${r.want}`);
    }
  }

  return parts.join("\n");
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

  const sourceSchema = testSchema.replace(/_(ut|it)$/, "");
  const isIntegration = testSchema.endsWith("_it");

  const filter = pattern ?? `^test_`;
  const ql = (s: string) => `'${s.replace(/'/g, "''")}'`;
  const qi = (s: string) => `"${s.replace(/"/g, '""')}"`;

  // Integration tests get pgv_ut in search_path (for assert_page and other test helpers)
  const extraSchemas = isIntegration ? `, ${qi("pgv_ut")}, ${qi("pgv")}` : "";

  // Detect if we're already inside a transaction (e.g. called from pg_func_set)
  const { rows: txCheck } = await client.query<{ in_tx: boolean }>(`SELECT now() != statement_timestamp() AS in_tx`);
  const inTransaction = txCheck[0]?.in_tx ?? false;

  // Use SET LOCAL inside a transaction so search_path is automatically
  // restored on COMMIT/ROLLBACK — no state leak on the pooled connection
  if (inTransaction) {
    await client.query("SAVEPOINT test_run");
  } else {
    await client.query("BEGIN");
  }
  await client.query(`SET LOCAL search_path TO ${qi(testSchema)}, ${qi(sourceSchema)}${extraSchemas}, public`);
  // PLX module tests run with a deterministic default session context.
  await client.query(`SET LOCAL app.tenant_id = 'test'`);
  const permissions = await inferTestPermissions(client, sourceSchema);
  if (permissions.length > 0) {
    await client.query(`SET LOCAL app.permissions = ${ql(permissions.join(","))}`);
  }
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
    if (inTransaction) {
      await client.query("RELEASE SAVEPOINT test_run");
    } else {
      await client.query("ROLLBACK");
    }
    if (rows.length === 0 && compiledTests.size === 0) {
      return { passed: 0, failed: 0, total: 0, results: [] };
    }
    const report = rows.length > 0 ? parseTap(rows) : { passed: 0, failed: 0, total: 0, results: [] as TapResult[] };

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
    if (inTransaction) {
      await client.query("ROLLBACK TO SAVEPOINT test_run").catch(() => {});
    } else {
      await client.query("ROLLBACK").catch(() => {});
    }
    const msg = err instanceof Error ? err.message : String(err);
    return {
      passed: 0,
      failed: 1,
      total: 1,
      results: [{ ok: false, description: `test execution error: ${msg}` }],
    };
  }
}

async function inferTestPermissions(client: DbClient, sourceSchema: string): Promise<string[]> {
  const { rows } = await client.query<{ proname: string }>(
    `SELECT p.proname
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = $1
      ORDER BY p.proname`,
    [sourceSchema],
  );

  const permissions = new Set<string>();
  for (const row of rows) {
    const name = row.proname;
    if (name.startsWith("_") || name.startsWith("on_")) continue;
    const match = name.match(/^([a-z0-9_]+)_(create|read|list|view|update|delete|[a-z0-9_]+)$/);
    if (!match) continue;
    const entity = match[1];
    const action = match[2];
    if (!entity || !action) continue;
    const normalized = action === "update" ? "modify" : action === "list" || action === "view" ? "read" : action;
    permissions.add(`${sourceSchema}.${entity}.${normalized}`);
  }

  return [...permissions].sort();
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

      if (!target && !schema) return text("✗ provide target (function URI) or schema (test schema)");

      return withClient(async (client) => {
        let testSchema: string;
        let testPattern: string | undefined = pattern;

        if (target) {
          const parsed = PlUri.parse(target);
          if (!parsed) {
            return text(`✗ invalid URI: ${target}`);
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
          const parsedTarget = target ? PlUri.parse(target) : null;
          const msg = target
            ? `no test found (expected ${testSchema}.test_${parsedTarget?.name ?? "unknown"})`
            : `no tests in ${testSchema}`;
          return text(msg);
        }

        return text(formatTestReport(report));
      });
    },
  };
}
