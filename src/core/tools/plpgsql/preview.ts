import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createPreviewTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "pg_preview",
      description:
        "Preview PL/pgSQL HTML output in the browser.\n" +
        "Executes a SQL expression that returns HTML and provides a preview URL.\n" +
        "The URL renders the HTML inside the pgView shell (PicoCSS + pgview.css).\n" +
        "Use for visual feedback during UI development.",
      schema: z.object({
        sql: z
          .string()
          .describe(
            "SQL expression returning HTML. Ex: pgv.breadcrumb('Home', '/', 'Page') or SELECT pgv_qa.get_atoms()",
          ),
      }),
    },
    handler: async (args, _extra) => {
      const sql = args.sql as string;

      // Validate the SQL returns something
      return withClient(async (client) => {
        try {
          const { rows } = await client.query(`SELECT (${sql})::text AS html`);
          const html = rows[0]?.html ?? "";
          const port = process.env.MCP_PORT ?? "3100";
          const previewUrl = `http://localhost:${port}/preview?sql=${encodeURIComponent(sql)}`;
          const snippet = html.length > 200 ? `${html.slice(0, 200)}...` : html;

          return text(
            [`preview: ${previewUrl}`, `html_length: ${html.length} chars`, "", `snippet:`, snippet].join("\n"),
          );
        } catch (err: unknown) {
          const msg = err instanceof Error ? err.message : String(err);
          return text(`problem: ${msg}\nwhere: pg_preview\nfix_hint: check the SQL expression syntax`);
        }
      });
    },
  };
}
