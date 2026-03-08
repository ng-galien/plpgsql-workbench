import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { DbClient } from "../connection.js";
import { PlUri } from "../uri.js";
import { text, withClient, formatErrorTriplet, type ToolResult } from "../helpers.js";
import { queryFunction, formatFunction } from "../resources/function.js";
import { runTests, formatTestReport } from "./test.js";
import { resolveUri } from "./get.js";

export async function setFunction(
  client: DbClient,
  schema: string,
  name: string,
  content: string,
): Promise<ToolResult> {
  await client.query("BEGIN");

  try {
    await client.query(content);
  } catch (err: unknown) {
    await client.query("ROLLBACK");
    return text(`✗ deploy failed\n${formatErrorTriplet(err, content, `${schema}.${name}`)}`);
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
    return text(`${validation}\n\ndeploy rolled back (fix errors and retry)`);
  }

  // Auto-run unit tests inside the transaction (before commit)
  let testSection = "";
  const utSchema = `${schema}_ut`;
  const testReport = await runTests(client, utSchema, `^test_${name}$`);
  if (testReport && testReport.total > 0) {
    if (testReport.failed > 0) {
      await client.query("ROLLBACK");
      return text(`${validation}\n---\n${formatTestReport(testReport)}\n\ndeploy rolled back (fix failing tests and retry)`);
    }
    testSection = `\n---\n${formatTestReport(testReport)}`;
  }

  await client.query("COMMIT");

  // Return deployed state
  const fn = await queryFunction(client, schema, name);
  const state = fn ? formatFunction(fn) : "";
  return text(`${validation}\n---\n${state}${testSection}`);
}

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
      return text(`✗ dry-run failed\n${formatErrorTriplet(err, content, `${parsed.schema}.${parsed.name}`)}`);
    }
  } catch (err: unknown) {
    return text(`✗ ${formatErrorTriplet(err)}`);
  }

  // Apply for real
  try {
    await client.query(content);
  } catch (err: unknown) {
    return text(`✗ deploy failed after dry-run\n${formatErrorTriplet(err, content, `${parsed.schema}.${parsed.name}`)}`);
  }

  // Return deployed state
  const state = await resolveUri(parsed.toString(), client);
  return text(`✓ deployed\n---\n${state}`);
}

export function registerSet(s: McpServer): void {
  s.tool(
    "set",
    "Deploy a PL/pgSQL object and validate it. On success, returns the deployed resource (same as get).\n" +
      "Functions: CREATE OR REPLACE + plpgsql_check. DDL: dry-run in transaction (BEGIN/ROLLBACK).",
    {
      uri: z.string().describe("Target URI. Ex: plpgsql://public/function/transfer"),
      content: z.string().describe("Full SQL statement. Ex: CREATE OR REPLACE FUNCTION ..."),
    },
    async ({ uri, content }) => {
      const parsed = PlUri.parse(uri);
      if (!parsed || !parsed.kind || !parsed.name) {
        return text(`✗ invalid URI: ${uri}`);
      }

      return withClient(async (client) => {
        if (parsed.kind === "function") {
          return await setFunction(client, parsed.schema, parsed.name!, content);
        } else {
          return await setDdl(client, parsed, content);
        }
      });
    },
  );
}
