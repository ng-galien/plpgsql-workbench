import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createAlterTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "pg_alter",
      description:
        "ALTER FUNCTION attributes without redeploying. Set SECURITY DEFINER, change owner, etc.\n" +
        "Can target a single function or all functions in a schema matching a pattern.\n" +
        "Example: schema=crm pattern=% security_definer=true → all crm functions become SECURITY DEFINER.",
      schema: z.object({
        uri: z.string().optional().describe("Single function URI. Ex: plpgsql://crm/function/client_create"),
        schema: z.string().optional().describe("Schema for bulk operations. Combined with pattern."),
        pattern: z
          .string()
          .optional()
          .describe("Function name pattern (LIKE) for bulk. Ex: %_create or %_delete. Default: % (all)"),
        security_definer: z.boolean().optional().describe("Set SECURITY DEFINER (true) or SECURITY INVOKER (false)"),
        owner: z.string().optional().describe("New owner role. Ex: postgres"),
      }),
    },
    handler: async (args, _extra) => {
      const uri = args.uri as string | undefined;
      const schema = args.schema as string | undefined;
      const pattern = (args.pattern as string) ?? "%";
      const securityDefiner = args.security_definer as boolean | undefined;
      const owner = args.owner as string | undefined;

      if (!uri && !schema) {
        return text("problem: provide either uri (single function) or schema (bulk)\nwhere: pg_alter");
      }

      if (securityDefiner === undefined && !owner) {
        return text("problem: nothing to alter — set security_definer or owner\nwhere: pg_alter");
      }

      return withClient(async (client) => {
        let targetSchema: string;
        let targetPattern: string;

        if (uri) {
          const match = uri.match(/^plpgsql:\/\/(\w+)\/function\/(\w+)$/);
          if (!match) {
            return text(`problem: invalid URI: ${uri}\nwhere: pg_alter`);
          }
          targetSchema = match[1]!;
          targetPattern = match[2]!;
        } else {
          targetSchema = schema!;
          targetPattern = pattern;
        }

        // Find matching functions
        const { rows } = await client.query<{ ident: string; name: string; secdef: boolean }>(
          `SELECT p.oid::regprocedure::text AS ident, p.proname AS name, p.prosecdef AS secdef
           FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           JOIN pg_language l ON l.oid = p.prolang
           WHERE n.nspname = $1 AND p.proname LIKE $2
             AND l.lanname IN ('plpgsql', 'sql')
           ORDER BY p.proname, p.oid`,
          [targetSchema, targetPattern],
        );

        if (rows.length === 0) {
          return text(`no functions matching ${targetSchema}.${targetPattern}\nwhere: pg_alter`);
        }

        const results: string[] = [];
        let altered = 0;
        let skipped = 0;

        for (const row of rows) {
          const alterParts: string[] = [];

          if (securityDefiner !== undefined) {
            if (securityDefiner === row.secdef) {
              skipped++;
              continue; // already in desired state
            }
            alterParts.push(securityDefiner ? "SECURITY DEFINER" : "SECURITY INVOKER");
          }

          if (owner) {
            alterParts.push(`OWNER TO ${owner}`);
          }

          if (alterParts.length === 0) {
            skipped++;
            continue;
          }

          try {
            await client.query(`ALTER FUNCTION ${row.ident} ${alterParts.join(" ")}`);
            results.push(`✓ ${row.ident} → ${alterParts.join(", ")}`);
            altered++;
          } catch (e: any) {
            results.push(`✗ ${row.ident} — ${e.message}`);
          }
        }

        // Re-grant after alter
        try {
          await client.query(`GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${targetSchema} TO anon`);
        } catch {
          /* ignore */
        }
        await client.query("NOTIFY pgrst, 'reload schema'").catch(() => {});

        return text(
          `completeness: full\n\n${results.join("\n")}${skipped > 0 ? `\n\n${skipped} already in desired state` : ""}\n\n${altered} function(s) altered in ${targetSchema}\n\nnext:\n  pg_func_save target: plpgsql://${targetSchema}\n  pg_pack schemas: ${targetSchema}`,
        );
      });
    },
  };
}
