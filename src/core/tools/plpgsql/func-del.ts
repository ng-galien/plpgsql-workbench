import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { validateContextToken } from "../../context-token.js";
import { text } from "../../helpers.js";
import { formatFunction, queryFunction } from "../../resources/function.js";
import { PlUri } from "../../uri.js";

export function createFuncDelTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "pg_func_del",
      description:
        "Drop a PL/pgSQL function. Use when a function signature changes and CREATE OR REPLACE cannot replace it.\n" +
        "Requires context_token (read before delete). Returns dropped function details.",
      schema: z.object({
        uri: z.string().describe("Target URI. Ex: plpgsql://cad/function/page_index"),
        context_token: z
          .string()
          .optional()
          .describe("Context token from pg_get. Required — proves the function was read before deletion."),
      }),
    },
    handler: async (args, _extra) => {
      const uri = args.uri as string;
      const contextToken = args.context_token as string | undefined;
      const parsed = PlUri.parse(uri);

      if (!parsed || parsed.kind !== "function" || !parsed.name) {
        return text(`problem: invalid URI: ${uri}\nwhere: pg_func_del\nfix_hint: use plpgsql://schema/function/name`);
      }

      const schema = parsed.schema;
      const name = parsed.name;

      return withClient(async (client) => {
        // Validate context token
        const tokenCheck = await validateContextToken(client, schema, name, contextToken);
        if (!tokenCheck.valid) {
          return text(`completeness: full\n\n✗ ${tokenCheck.reason}`);
        }

        // Get function identity (full signature via regprocedure)
        const identRes = await client.query<{ ident: string }>(
          `SELECT p.oid::regprocedure::text AS ident
           FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = $1 AND p.proname = $2 LIMIT 1`,
          [schema, name],
        );

        if (identRes.rows.length === 0) {
          return text(
            `completeness: full\n\nproblem: function ${schema}.${name} not found\nwhere: pg_func_del\nfix_hint: check schema and function name`,
          );
        }

        const ident = identRes.rows[0].ident;

        // Capture function state before deletion
        const fn = await queryFunction(client, schema, name);
        const stateBefore = fn ? formatFunction(fn) : `${schema}.${name}`;

        // Drop
        await client.query(`DROP FUNCTION ${ident}`);
        await client.query("NOTIFY pgrst, 'reload schema'").catch(() => {});

        return text(
          `completeness: full\n\n✓ dropped ${ident}\n---\n${stateBefore}\n\nnext:\n  pg_func_set to recreate with new signature\n  pg_get plpgsql://${schema} to verify`,
        );
      });
    },
  };
}
