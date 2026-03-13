import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createExplainTool({ withClient }: {
  withClient: WithClient;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_explain",
      description:
        "Run EXPLAIN ANALYZE on a SQL query. Returns the query execution plan with timing.\n" +
        "WARNING: EXPLAIN ANALYZE actually executes the query. Do NOT use with INSERT/UPDATE/DELETE unless intended.",
      schema: z.object({
        sql: z.string().describe("SQL query to explain"),
      }),
    },
    handler: async (args, _extra) => {
      const sql = args.sql as string;
      return withClient(async (client) => {
        // Run inside a transaction that always rolls back to prevent side effects
        // (EXPLAIN ANALYZE actually executes the query)
        await client.query("BEGIN");
        try {
          const { rows } = await client.query<{ "QUERY PLAN": string }>(
            `EXPLAIN ANALYZE ${sql}`,
          );
          return text(`completeness: full\n\n${rows.map((r) => r["QUERY PLAN"]).join("\n")}`);
        } catch (err: unknown) {
          const msg = err instanceof Error ? err.message : String(err);
          return text(`problem: ${msg}\nwhere: pg_explain\nfix_hint: check SQL syntax`);
        } finally {
          await client.query("ROLLBACK");
        }
      });
    },
  };
}
