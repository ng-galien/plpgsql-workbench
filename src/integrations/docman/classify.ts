import { z } from "zod";
import type { ToolHandler, WithClient } from "../../core/container.js";
import { text } from "../../core/helpers.js";

export function createDocClassifyTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_classify",
      description:
        "Set document metadata: type, date, and summary.\n" +
        "Marks the document as classified. All fields are optional (only updates provided ones).\n" +
        "Use doc_tag / doc_link / doc_relate for labels, entities, and relations.",
      schema: z.object({
        id: z.string().describe("Document UUID"),
        doc_type: z.string().optional().describe("Document type: facture, devis, contrat, courrier, releve..."),
        document_date: z.string().optional().describe("Business date (ISO: 2024-03-15)"),
        summary: z.string().optional().describe("AI-generated summary"),
      }),
    },
    handler: async (args) => {
      const { id, doc_type, document_date, summary } = args as {
        id: string;
        doc_type?: string;
        document_date?: string;
        summary?: string;
      };

      return await withClient(async (client) => {
        await client.query(`SELECT docman.classify($1, $2, $3::date, $4)`, [
          id,
          doc_type ?? null,
          document_date ?? null,
          summary ?? null,
        ]);

        const parts = [`Classified: ${id}`];
        if (doc_type) parts.push(`type: ${doc_type}`);
        if (document_date) parts.push(`date: ${document_date}`);
        if (summary) parts.push(`summary: ${summary}`);

        return text(
          parts.join("\n") +
            `\n\nnext:\n  - doc_tag id:${id} label:... to assign labels\n  - doc_link id:${id} kind:... name:... role:... to link entities`,
        );
      });
    },
  };
}
