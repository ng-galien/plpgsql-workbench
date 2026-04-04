import { z } from "zod";
import type { ToolHandler, WithClient } from "../../core/container.js";
import { text } from "../../core/helpers.js";

const MAX_QUERY_ROWS = 100;

export function createQueryTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "pg_query",
      description:
        "Execute raw SQL. Returns key:value rows for SELECT, row count for DML.\n" +
        "Use pg_get/pg_search to navigate objects. Use pg_query only for ad-hoc SQL or DML.\n" +
        "Results are truncated at 100 rows.",
      schema: z.object({
        sql: z.string().describe("SQL statement"),
      }),
    },
    handler: async (args, _extra) => {
      const sql = args.sql as string;
      return withClient(async (client) => {
        const start = Date.now();
        try {
          const result = await client.query(sql);
          const duration = Date.now() - start;

          if (!result.rows || result.rows.length === 0) {
            return text(`OK (${result.rowCount ?? 0} rows affected, ${duration}ms)`);
          }

          const fields = (result.fields ?? []).map((f: { name: string }) => f.name);
          const totalRows = result.rows.length;
          const truncated = totalRows > MAX_QUERY_ROWS;
          const displayRows = truncated ? result.rows.slice(0, MAX_QUERY_ROWS) : result.rows;
          const completeness = truncated ? "partial" : "full";
          const footer = truncated
            ? `(${MAX_QUERY_ROWS} of ${totalRows} rows, ${duration}ms)`
            : `(${totalRows} rows, ${duration}ms)`;

          const header = `completeness: ${completeness}\ncolumns: ${fields.join(", ")}`;
          const rows = displayRows.map((r: Record<string, unknown>, idx: number) => {
            const kvs = fields.map((f: string) => `  ${f}: ${String(r[f] ?? "NULL")}`);
            return `row ${idx + 1}:\n${kvs.join("\n")}`;
          });

          return text(`${header}\n\n${rows.join("\n")}\n${footer}`);
        } catch (err: unknown) {
          return text(`✗ ${err instanceof Error ? err.message : String(err)}`);
        }
      });
    },
  };
}
