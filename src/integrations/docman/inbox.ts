import { z } from "zod";
import type { ToolHandler, WithClient } from "../../core/container.js";
import { text } from "../../core/helpers.js";

export function createDocInboxTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_inbox",
      description:
        "List unclassified documents, or documents classified with low confidence.\n" +
        "Returns documents pending classification or review.",
      schema: z.object({
        limit: z.number().optional().describe("Max results (default 20)"),
        max_confidence: z.number().optional().describe("Include docs classified below this confidence (0.0-1.0)"),
      }),
    },
    handler: async (args) => {
      const { limit = 20, max_confidence } = args as { limit?: number; max_confidence?: number };

      return await withClient(async (client) => {
        const res = await client.query(`SELECT * FROM docman.inbox($1, $2)`, [limit, max_confidence ?? null]);

        if (res.rows.length === 0) {
          return text("Inbox is empty — all documents are classified.");
        }

        const lines = res.rows.map(
          (r: any) =>
            `${r.filename}  ${r.extension || "?"}  ${r.source}  ${Math.round(r.size_bytes / 1024)}KB` +
            (r.doc_type ? `  [${r.doc_type}]` : "") +
            `\n  id: ${r.id}\n  path: ${r.file_path}`,
        );

        return text(
          `Unclassified: ${res.rows.length} shown\n\n` +
            lines.join("\n\n") +
            `\n\nnext:\n  - doc_peek id:<id> to read a document\n  - doc_classify id:<id> doc_type:... summary:...`,
        );
      });
    },
  };
}
