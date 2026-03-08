import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import type { ToolResult } from "../../helpers.js";
import { text, formatErrorTriplet } from "../../helpers.js";
import { PlUri } from "../../uri.js";
import { queryFunction, formatFunction } from "../../resources/function.js";
import type { TestReport } from "./test.js";

// --- Service types ---

export type SetFunctionFn = (
  client: DbClient, schema: string, name: string, content: string,
) => Promise<ToolResult>;

type RunTestsFn = (
  client: DbClient, testSchema: string, pattern?: string,
) => Promise<TestReport | null>;

type FormatTestReportFn = (report: TestReport) => string;

type ResolveUriFn = (uri: string, client: DbClient) => Promise<string>;

// --- Shared service factory (injected into edit + set tools) ---

export function createSetFunction({ runTests, formatTestReport }: {
  runTests: RunTestsFn;
  formatTestReport: FormatTestReportFn;
}): SetFunctionFn {
  return async (client, schema, name, content) => {
    await client.query("BEGIN");

    try {
      await client.query(content);
    } catch (err: unknown) {
      await client.query("ROLLBACK");
      return text(`completeness: full\n\n✗ deploy failed\n${formatErrorTriplet(err, content, `${schema}.${name}`)}`);
    }

    // Validation
    let validation = "";
    let hasErrors = false;
    try {
      const check = await client.query<{ lineno: number; message: string; hint: string | null; level: string; statement: string | null }>(
        `SELECT lineno, message, hint, level, statement FROM plpgsql_check_function_tb($1)`,
        [`${schema}.${name}`],
      );
      if (check.rows.length === 0) {
        validation = "✓ plpgsql_check passed";
      } else {
        hasErrors = check.rows.some((r) => r.level === "error");
        const diag = check.rows.map((r) => {
          const parts = [`problem: ${r.message}`, `where: line ${r.lineno}`];
          if (r.statement) parts.push(`statement: ${r.statement}`);
          if (r.hint) parts.push(`fix_hint: ${r.hint}`);
          return `  [${r.level}]\n  ${parts.join("\n  ")}`;
        }).join("\n");
        const sym = hasErrors ? "✗" : "⚠";
        validation = `${sym} plpgsql_check:\n${diag}`;
      }
    } catch {
      validation = "✓ deployed (plpgsql_check not available)";
    }

    if (hasErrors) {
      await client.query("ROLLBACK");
      return text(`completeness: full\n\n${validation}\n\ndeploy rolled back (fix errors and retry)`);
    }

    // Auto-run unit tests inside the transaction (before commit)
    let testSection = "";
    const utSchema = `${schema}_ut`;
    const testReport = await runTests(client, utSchema, `^test_${name}$`);
    if (testReport && testReport.total > 0) {
      if (testReport.failed > 0) {
        await client.query("ROLLBACK");
        return text(`completeness: full\n\n${validation}\n---\n${formatTestReport(testReport)}\n\ndeploy rolled back (fix failing tests and retry)`);
      }
      testSection = `\n---\n${formatTestReport(testReport)}`;
    }

    await client.query("COMMIT");

    // Return deployed state
    const fn = await queryFunction(client, schema, name);
    const state = fn ? formatFunction(fn) : "";
    return text(`completeness: full\n\n${validation}\n---\n${state}${testSection}`);
  };
}

// --- Tool factory ---

export function createSetTool({ withClient, setFunction, resolveUri }: {
  withClient: WithClient;
  setFunction: SetFunctionFn;
  resolveUri: ResolveUriFn;
}): ToolHandler {
  async function setDdl(
    client: DbClient,
    parsed: PlUri,
    content: string,
  ): Promise<ToolResult> {
    try {
      await client.query("BEGIN");
      try {
        await client.query(content);
        await client.query("ROLLBACK");
      } catch (err: unknown) {
        await client.query("ROLLBACK");
        return text(`completeness: full\n\n✗ dry-run failed\n${formatErrorTriplet(err, content, `${parsed.schema}.${parsed.name}`)}`);
      }
    } catch (err: unknown) {
      return text(`completeness: full\n\n✗ ${formatErrorTriplet(err)}`);
    }

    // Apply for real
    try {
      await client.query(content);
    } catch (err: unknown) {
      return text(`completeness: full\n\n✗ deploy failed after dry-run\n${formatErrorTriplet(err, content, `${parsed.schema}.${parsed.name}`)}`);
    }

    // Return deployed state
    const state = await resolveUri(parsed.toString(), client);
    return text(`completeness: full\n\n✓ deployed\n---\n${state}`);
  }

  return {
    metadata: {
      name: "pg_set",
      description:
        "Deploy a PL/pgSQL object and validate it. On success, returns the deployed resource (same as get).\n" +
        "Functions: CREATE OR REPLACE + plpgsql_check. DDL: dry-run in transaction (BEGIN/ROLLBACK).",
      schema: z.object({
        uri: z.string().describe("Target URI. Ex: plpgsql://public/function/transfer"),
        content: z.string().describe("Full SQL statement. Ex: CREATE OR REPLACE FUNCTION ..."),
      }),
    },
    handler: async (args, _extra) => {
      const uri = args.uri as string;
      const content = args.content as string;
      const parsed = PlUri.parse(uri);
      if (!parsed || !parsed.kind || !parsed.name) {
        return text(`problem: invalid URI: ${uri}\nwhere: pg_set\nfix_hint: use plpgsql://schema/kind/name`);
      }

      return withClient(async (client) => {
        if (parsed.kind === "function") {
          return await setFunction(client, parsed.schema, parsed.name!, content);
        } else {
          return await setDdl(client, parsed, content);
        }
      });
    },
  };
}
