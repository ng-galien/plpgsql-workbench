import { z } from "zod";
import type { ToolHandler, WithClient } from "../../core/container.js";
import { text } from "../../core/helpers.js";

export function createFuncBulkDelTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "pg_func_bulk_del",
      description:
        "Drop multiple PL/pgSQL functions by pattern. Use for bulk cleanup after renames.\n" +
        "Pattern matches function name with LIKE. Use % as wildcard. No context_token required.\n" +
        "Example: schema=crm pattern=post_devis_% drops all post_devis_* functions.",
      schema: z.object({
        schema: z.string().describe("Schema name. Ex: crm"),
        pattern: z.string().describe("Function name pattern with % wildcard. Ex: post_devis_%"),
        dry_run: z.boolean().optional().describe("If true, list matching functions without dropping (default: false)"),
      }),
    },
    handler: async (args, _extra) => {
      const schema = args.schema as string;
      const pattern = args.pattern as string;
      const dryRun = (args.dry_run as boolean) ?? false;

      return withClient(async (client) => {
        const { rows } = await client.query<{ ident: string; name: string }>(
          `SELECT p.oid::regprocedure::text AS ident, p.proname AS name
           FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = $1 AND p.proname LIKE $2
           ORDER BY p.proname, p.oid`,
          [schema, pattern],
        );

        if (rows.length === 0) {
          return text(`completeness: full\n\nno functions matching ${schema}.${pattern}`);
        }

        if (dryRun) {
          const list = rows.map((r) => `  ${r.ident}`).join("\n");
          return text(
            `completeness: full\n\ndry run — ${rows.length} function(s) would be dropped:\n${list}\n\nRe-run with dry_run:false to execute.`,
          );
        }

        const results: string[] = [];
        let dropped = 0;

        await client.query("BEGIN");
        try {
          for (const row of rows) {
            await client.query(`DROP FUNCTION ${row.ident}`);
            results.push(`✓ dropped ${row.ident}`);
            dropped++;
          }
          await client.query("COMMIT");
          await client.query("NOTIFY pgrst, 'reload schema'").catch(() => {});
        } catch (e: any) {
          await client.query("ROLLBACK").catch(() => {});
          return text(`✗ bulk delete failed after ${dropped} drops\nproblem: ${e.message}\nwhere: pg_func_bulk_del`);
        }

        return text(
          `completeness: full\n\n${results.join("\n")}\n\n${dropped} function(s) dropped matching ${schema}.${pattern}\n\nnext:\n  pg_func_save target: plpgsql://${schema}\n  pg_pack schemas: ${schema}`,
        );
      });
    },
  };
}
