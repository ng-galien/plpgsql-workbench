import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { type CoverageResult, formatCoverageReport, runCoverage } from "../../instrument/coverage.js";
import { PlUri } from "../../uri.js";
import type { TestReport } from "./test.js";

type RunTestsFn = (client: DbClient, testSchema: string, pattern?: string) => Promise<TestReport | null>;

export function createCoverageTool({
  withClient,
  runTests,
}: {
  withClient: WithClient;
  runTests: RunTestsFn;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_coverage",
      description:
        "Run code coverage analysis on a PL/pgSQL function or entire schema.\n" +
        "Single function: plpgsql://schema/function/name\n" +
        "Batch schema: plpgsql://schema — runs coverage on all plpgsql functions that have a test.\n" +
        "Instruments functions, runs unit tests, then restores originals.\n" +
        "Reports block + branch coverage with aggregated schema score.",
      schema: z.object({
        target: z.string().describe("Function or schema URI. Ex: plpgsql://pgv or plpgsql://pgv/function/route"),
      }),
    },
    handler: async (args, _extra) => {
      const target = args.target as string;
      const parsed = PlUri.parse(target);
      if (!parsed) {
        return text(
          "problem: invalid URI\nwhere: pg_coverage\nfix_hint: use plpgsql://schema or plpgsql://schema/function/name",
        );
      }

      // Schema-level batch coverage
      if (!parsed.kind && !parsed.name) {
        return withClient(async (client) => {
          return await runSchemaCoverage(client, parsed.schema, runTests);
        });
      }

      // Single function coverage
      if (parsed.kind !== "function" || !parsed.name) {
        return text(
          "problem: target must be a function or schema URI\nwhere: pg_coverage\nfix_hint: use plpgsql://schema or plpgsql://schema/function/name",
        );
      }

      return withClient(async (client) => {
        const utSchema = `${parsed.schema}_ut`;
        const testPattern = `^test_${parsed.name}$`;

        const result = await runCoverage(client, parsed.schema, parsed.name!, async (c) => {
          await runTests(c, utSchema, testPattern);
        });

        if (!result) {
          return text(
            `problem: function ${parsed.schema}.${parsed.name} not found\nwhere: pg_coverage\nfix_hint: check the target URI`,
          );
        }

        if (result.totalPoints === 0) {
          return text(`completeness: full\n\n${parsed.schema}.${parsed.name}: no coverage points (empty function?)`);
        }

        return text(`completeness: full\n\n${formatCoverageReport(result)}`);
      });
    },
  };
}

async function runSchemaCoverage(
  client: DbClient,
  schema: string,
  runTests: RunTestsFn,
): Promise<ReturnType<typeof text>> {
  const utSchema = `${schema}_ut`;

  // 1. List all functions in the schema
  const { rows: allFns } = await client.query(
    `SELECT p.proname AS name, l.lanname AS lang
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     JOIN pg_language l ON l.oid = p.prolang
     WHERE n.nspname = $1 AND p.prokind = 'f'
     ORDER BY p.proname`,
    [schema],
  );

  if (allFns.length === 0) {
    return text(`problem: no functions found in schema '${schema}'\nwhere: pg_coverage`);
  }

  // 2. Check which tests exist
  const { rows: testFns } = await client.query(
    `SELECT p.proname AS name
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = $1 AND p.proname LIKE 'test\\_%'`,
    [utSchema],
  );
  const testSet = new Set(testFns.map((r: any) => r.name.replace(/^test_/, "")));

  // Categorize
  const plpgsqlFns = allFns.filter((r: any) => r.lang === "plpgsql");
  const sqlFns = allFns.filter((r: any) => r.lang === "sql");
  const withTest = plpgsqlFns.filter((r: any) => testSet.has(r.name));
  const noTest = plpgsqlFns.filter((r: any) => !testSet.has(r.name));

  // 3. Run coverage on each testable function
  const results: CoverageResult[] = [];
  const errors: string[] = [];

  for (const fn of withTest) {
    try {
      const result = await runCoverage(client, schema, fn.name, async (c) => {
        await runTests(c, utSchema, `^test_${fn.name}$`);
      });
      if (result) results.push(result);
    } catch (err) {
      errors.push(`${fn.name}: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  // 4. Format aggregated report
  const lines: string[] = [];
  lines.push(`completeness: full`);
  lines.push(`schema: ${schema}`);
  lines.push(`functions: ${allFns.length} total, ${plpgsqlFns.length} plpgsql, ${sqlFns.length} sql`);
  lines.push(`tested: ${withTest.length}, untested: ${noTest.length}`);
  lines.push("");

  let totalPoints = 0;
  let totalHit = 0;

  if (results.length > 0) {
    lines.push("function | blocks | branches | coverage");
    lines.push("---------|--------|----------|--------");
    for (const r of results.sort((a, b) => a.percentage - b.percentage)) {
      const blocks = r.points.filter((p) => p.kind === "block");
      const branches = r.points.filter((p) => p.kind === "branch");
      const hitBlocks = blocks.filter((p) => r.hit.has(p.id)).length;
      const hitBranches = branches.filter((p) => r.hit.has(p.id)).length;
      const sym = r.percentage === 100 ? "✓" : r.percentage >= 80 ? "⚠" : "✗";
      lines.push(
        `${sym} ${r.name} | ${hitBlocks}/${blocks.length} | ${hitBranches}/${branches.length} | ${r.percentage}%`,
      );
      totalPoints += r.totalPoints;
      totalHit += r.coveredPoints;
    }
    const globalPct = totalPoints > 0 ? Math.round((totalHit / totalPoints) * 100) : 100;
    lines.push("");
    lines.push(`schema score: ${globalPct}% (${totalHit}/${totalPoints} points)`);
  }

  if (noTest.length > 0) {
    lines.push("");
    lines.push(`untested (${noTest.length}):`);
    for (const fn of noTest) {
      lines.push(`  - ${fn.name}`);
    }
  }

  if (sqlFns.length > 0) {
    lines.push("");
    lines.push(`sql pure — n/a (${sqlFns.length}):`);
    for (const fn of sqlFns) {
      lines.push(`  - ${fn.name}`);
    }
  }

  if (errors.length > 0) {
    lines.push("");
    lines.push(`errors (${errors.length}):`);
    for (const e of errors) {
      lines.push(`  - ${e}`);
    }
  }

  return text(lines.join("\n"));
}
