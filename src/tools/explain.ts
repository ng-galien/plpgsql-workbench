import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { text, withClient } from "../helpers.js";

export function registerExplain(s: McpServer): void {
  s.tool(
    "explain",
    "Run EXPLAIN ANALYZE on a SQL query. Returns the query execution plan with timing.",
    { sql: z.string().describe("SQL query to explain") },
    async ({ sql }) => withClient(async (client) => {
      try {
        const { rows } = await client.query<{ "QUERY PLAN": string }>(
          `EXPLAIN ANALYZE ${sql}`,
        );
        return text(rows.map((r) => r["QUERY PLAN"]).join("\n"));
      } catch (err: unknown) {
        return text(`✗ ${err instanceof Error ? err.message : String(err)}`);
      }
    }),
  );
}
