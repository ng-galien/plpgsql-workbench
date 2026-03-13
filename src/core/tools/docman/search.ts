import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createDocSearchTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_search",
      description:
        "Search documents by name, type, date, label, entity, full-text, or source.\n" +
        "All filters are optional and combined with AND.",
      schema: z.object({
        name: z.string().optional().describe("Filename pattern (ILIKE, use % as wildcard)"),
        doc_type: z.string().optional().describe("Document type (facture, contrat...)"),
        label: z.string().optional().describe("Label name"),
        entity: z.string().optional().describe("Entity name"),
        extension: z.string().optional().describe("File extension (e.g. '.pdf')"),
        source: z.string().optional().describe("Source: filesystem, email"),
        after: z.string().optional().describe("Document date after (ISO date)"),
        before: z.string().optional().describe("Document date before (ISO date)"),
        q: z.string().optional().describe("Full-text search on summary"),
        classified: z.boolean().optional().describe("true = classified only, false = unclassified only"),
        limit: z.number().optional().describe("Max results (default 30)"),
      }),
    },
    handler: async (args) => {
      const filters = args as Record<string, unknown>;

      return await withClient(async (client) => {
        const res = await client.query(
          `SELECT docman.search($1)`,
          [JSON.stringify(filters)]
        );

        const docs = res.rows[0]?.search ?? [];

        if (docs.length === 0) {
          return text("No documents found matching the criteria.");
        }

        const lines = docs.map((r: any) => {
          const size = Math.round((r.size_bytes ?? 0) / 1024);
          return (
            `${r.filename}  ${r.extension || "?"}  ${size}KB  [${r.doc_type || "untyped"}]` +
            (r.document_date ? `  ${r.document_date}` : "") +
            `\n  id: ${r.id}\n  path: ${r.file_path}` +
            (r.summary ? `\n  summary: ${r.summary}` : "")
          );
        });

        return text(
          `Found ${docs.length} documents\n\n` +
          lines.join("\n\n") +
          `\n\nnext:\n  - doc_peek id:<id> to read content\n  - doc_classify id:<id> ...`
        );
      });
    },
  };
}
