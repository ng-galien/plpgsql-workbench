import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import type { ToolResult } from "../../helpers.js";
import { text, formatErrorTriplet } from "../../helpers.js";
import { PlUri } from "../../uri.js";
import { queryFunction, formatFunction } from "../../resources/function.js";
import { computeContextToken, validateContextToken } from "../../context-token.js";
import type { TestReport } from "./test.js";

// --- Service types ---

export type SetFunctionFn = (
  client: DbClient, schema: string, name: string, content: string, description?: string, contextToken?: string,
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
  return async (client, schema, name, content, description?, contextToken?) => {
    // Validate context token (proves agent has read the function)
    const tokenCheck = await validateContextToken(client, schema, name, contextToken);
    if (!tokenCheck.valid) {
      return text(`completeness: full\n\n✗ ${tokenCheck.reason}`);
    }

    // Count existing overloads before deploy
    const beforeCount = await client.query<{ count: string }>(
      `SELECT count(*)::text FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = $1 AND p.proname = $2`,
      [schema, name],
    );
    const overloadsBefore = parseInt(beforeCount.rows[0]?.count ?? "0");

    await client.query("BEGIN");

    try {
      await client.query(content);
    } catch (err: unknown) {
      await client.query("ROLLBACK");
      return text(`completeness: full\n\n✗ deploy failed\n${formatErrorTriplet(err, content, `${schema}.${name}`)}`);
    }

    // Detect new overloads
    const afterCount = await client.query<{ count: string }>(
      `SELECT count(*)::text FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = $1 AND p.proname = $2`,
      [schema, name],
    );
    const overloadsAfter = parseInt(afterCount.rows[0]?.count ?? "0");
    if (overloadsAfter > 1 && overloadsAfter > overloadsBefore) {
      await client.query("ROLLBACK");
      return text(
        `completeness: full\n\n` +
        `✗ overload interdit: ${schema}.${name} a deja ${overloadsBefore} signature(s).\n` +
        `  Ce deploy cree une nouvelle surcharge (${overloadsAfter} total).\n` +
        `  Les overloads causent des bugs de routing implicite.\n` +
        `  fix_hint: renomme la fonction ou supprime l'ancienne signature d'abord.\n` +
        `  Use pg_get plpgsql://${schema}/function/${name} to see existing signatures.\n\n` +
        `deploy rolled back`,
      );
    }

    // Validation: plpgsql_check only works on plpgsql functions
    let validation = "";
    let hasErrors = false;

    const langRes = await client.query<{ lang: string }>(
      `SELECT l.lanname AS lang FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
       JOIN pg_language l ON l.oid = p.prolang
       WHERE n.nspname = $1 AND p.proname = $2 LIMIT 1`,
      [schema, name],
    );
    const lang = langRes.rows[0]?.lang;

    if (lang !== "plpgsql") {
      validation = `✓ deployed (${lang} function, plpgsql_check skipped)`;
    } else {
      try {
        await client.query("SAVEPOINT plpgsql_check");
        const check = await client.query<{ lineno: number; message: string; hint: string | null; level: string; statement: string | null }>(
          `SELECT lineno, message, hint, level, statement FROM plpgsql_check_function_tb($1)`,
          [`${schema}.${name}`],
        );
        await client.query("RELEASE SAVEPOINT plpgsql_check");
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
        await client.query("ROLLBACK TO SAVEPOINT plpgsql_check").catch(() => {});
        validation = "✓ deployed (plpgsql_check not available)";
      }
    }

    if (hasErrors) {
      await client.query("ROLLBACK");
      return text(`completeness: full\n\n${validation}\n\ndeploy rolled back (fix errors and retry)`);
    }

    // Boundary check: detect cross-schema calls to _internal() functions
    try {
      await client.query("SAVEPOINT boundary_check");
      const deps = await client.query<{ type: string; schema: string; name: string }>(
        `SELECT type, schema, name FROM plpgsql_show_dependency_tb(
          (SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = $1 AND p.proname = $2 LIMIT 1)
        )`,
        [schema, name],
      );
      await client.query("RELEASE SAVEPOINT boundary_check");

      const violations = deps.rows.filter(
        (d) => d.type === "FUNCTION" && d.schema !== schema && d.name.startsWith("_"),
      );
      if (violations.length > 0) {
        const details = violations.map((v) => `  ${v.schema}.${v.name}`).join("\n");
        await client.query("ROLLBACK");
        return text(
          `completeness: full\n\n${validation}\n\n` +
          `✗ boundary violation: cross-schema calls to internal (_prefix) functions:\n${details}\n\n` +
          `Convention: schema._name() = interne, cross-module interdit.\n` +
          `deploy rolled back`,
        );
      }
    } catch {
      await client.query("ROLLBACK TO SAVEPOINT boundary_check").catch(() => {});
      // plpgsql_check not available — skip boundary check
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

    // Notify PostgREST to reload schema cache
    await client.query("NOTIFY pgrst, 'reload schema'").catch(() => {});

    // Apply COMMENT ON FUNCTION if description provided
    if (description) {
      const { rows: [{ ident }] } = await client.query<{ ident: string }>(
        `SELECT p.oid::regprocedure::text AS ident
         FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = $1 AND p.proname = $2 LIMIT 1`,
        [schema, name],
      );
      if (ident) {
        const escaped = description.replace(/'/g, "''");
        await client.query(`COMMENT ON FUNCTION ${ident} IS '${escaped}'`);
      }
    }

    // Return deployed state with new context token
    const fn = await queryFunction(client, schema, name);
    const state = fn ? formatFunction(fn) : "";
    const newToken = await computeContextToken(client, schema, name);
    const tokenLine = newToken ? `\n  context_token: ${newToken}` : "";
    return text(`completeness: full\n\n${validation}\n---\n${state}${tokenLine}${testSection}`);
  };
}

// --- Tool factory ---

export function createFuncSetTool({ withClient, setFunction, resolveUri }: {
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
      name: "pg_func_set",
      description:
        "Deploy a PL/pgSQL function and validate it. Pipeline: CREATE OR REPLACE + plpgsql_check + auto-test.\n" +
        "On success, returns the deployed resource. Also handles DDL dry-run in transaction (BEGIN/ROLLBACK).",
      schema: z.object({
        uri: z.string().describe("Target URI. Ex: plpgsql://public/function/transfer"),
        content: z.string().describe("Full SQL statement. Ex: CREATE OR REPLACE FUNCTION ..."),
        description: z.string().optional().describe("Function doc (COMMENT ON FUNCTION). Short description of what the function does."),
        context_token: z.string().optional().describe("Context token from pg_get. Required when modifying an existing function. Proves the function was read before modification."),
      }),
    },
    handler: async (args, _extra) => {
      const uri = args.uri as string;
      const content = args.content as string;
      const description = args.description as string | undefined;
      const contextToken = args.context_token as string | undefined;
      const parsed = PlUri.parse(uri);
      if (!parsed || !parsed.kind || !parsed.name) {
        return text(`problem: invalid URI: ${uri}\nwhere: pg_func_set\nfix_hint: use plpgsql://schema/kind/name`);
      }

      return withClient(async (client) => {
        if (parsed.kind === "function") {
          return await setFunction(client, parsed.schema, parsed.name!, content, description, contextToken);
        } else {
          return await setDdl(client, parsed, content);
        }
      });
    },
  };
}
