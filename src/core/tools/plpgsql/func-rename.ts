import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createFuncRenameTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "pg_func_rename",
      description:
        "Rename a PL/pgSQL function. Copies DDL with new name, drops old, re-grants.\n" +
        "Use for language renames or refactoring. No context_token required.",
      schema: z.object({
        uri: z.string().describe("Source function URI. Ex: plpgsql://crm/function/old_name"),
        new_name: z.string().describe("New function name (without schema). Ex: new_name"),
      }),
    },
    handler: async (args, _extra) => {
      const uri = args.uri as string;
      const newName = args.new_name as string;

      const match = uri.match(/^plpgsql:\/\/(\w+)\/function\/(\w+)$/);
      if (!match) {
        return text(`problem: invalid URI: ${uri}\nwhere: pg_func_rename\nfix_hint: use plpgsql://schema/function/old_name`);
      }

      const [, schema, oldName] = match;

      if (oldName === newName) {
        return text(`problem: old and new names are the same\nwhere: pg_func_rename`);
      }

      return withClient(async (client) => {
        // Get all overloads of the old function
        const { rows } = await client.query<{ oid: string; ident: string; ddl: string }>(
          `SELECT p.oid::text, p.oid::regprocedure::text AS ident, pg_get_functiondef(p.oid) AS ddl
           FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = $1 AND p.proname = $2
           ORDER BY p.oid`,
          [schema, oldName],
        );

        if (rows.length === 0) {
          return text(
            `problem: function ${schema}.${oldName} not found\nwhere: pg_func_rename`,
          );
        }

        const results: string[] = [];

        await client.query("BEGIN");
        try {
          for (const row of rows) {
            // Replace function name in DDL
            const newDdl = row.ddl.replace(
              new RegExp(`(CREATE\\s+OR\\s+REPLACE\\s+FUNCTION\\s+${schema}\\.)${oldName}\\b`, "i"),
              `$1${newName}`,
            );

            if (newDdl === row.ddl) {
              results.push(`⚠ could not replace name in DDL for overload ${row.ident}`);
              continue;
            }

            // Create new function
            await client.query(newDdl);

            // Copy COMMENT if exists
            const { rows: commentRows } = await client.query<{ desc: string }>(
              `SELECT obj_description($1::oid) AS desc`,
              [row.oid],
            );
            if (commentRows[0]?.desc) {
              const newIdent = row.ident.replace(
                new RegExp(`${schema}\\.${oldName}\\(`),
                `${schema}.${newName}(`,
              );
              const escaped = commentRows[0].desc.replace(/'/g, "''");
              await client.query(`COMMENT ON FUNCTION ${newIdent} IS '${escaped}'`);
            }

            // Drop old function
            await client.query(`DROP FUNCTION ${row.ident}`);
            results.push(`✓ ${row.ident} → ${schema}.${newName}`);
          }

          // Re-grant
          await client.query(`GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${schema} TO anon`);
          await client.query("COMMIT");
          await client.query("NOTIFY pgrst, 'reload schema'").catch(() => {});
        } catch (e: any) {
          await client.query("ROLLBACK").catch(() => {});
          return text(
            `✗ rename failed\nproblem: ${e.message}\nwhere: pg_func_rename\nfix_hint: check function dependencies`,
          );
        }

        return text(
          `completeness: full\n\n${results.join("\n")}\n\n${rows.length} overload(s) renamed: ${schema}.${oldName} → ${schema}.${newName}\n\nnext:\n  pg_func_save target: plpgsql://${schema}\n  pg_pack schemas: ${schema}`,
        );
      });
    },
  };
}
