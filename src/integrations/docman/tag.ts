import { z } from "zod";
import type { ToolHandler, WithClient } from "../../core/container.js";
import { text } from "../../core/helpers.js";

export function createDocTagTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_tag",
      description:
        "Assign a label to a document. Creates the label on-the-fly if it doesn't exist.\n" +
        "Resolves aliases: if the label name matches an existing alias, uses the canonical label.\n" +
        "Categories can be nested via parent. Tags are flat.",
      schema: z.object({
        id: z.string().describe("Document UUID"),
        label: z.string().describe("Label name"),
        kind: z.enum(["category", "tag"]).optional().describe("Label kind (default: tag)"),
        parent: z.string().optional().describe("Parent category name (for nested categories)"),
        confidence: z.number().optional().describe("Classification confidence 0.0-1.0 (default: 1.0)"),
      }),
    },
    handler: async (args) => {
      const {
        id,
        label,
        kind = "tag",
        parent,
        confidence = 1.0,
      } = args as {
        id: string;
        label: string;
        kind?: string;
        parent?: string;
        confidence?: number;
      };

      return await withClient(async (client) => {
        const res = await client.query(`SELECT docman.tag($1, $2, $3, $4, $5)`, [
          id,
          label,
          kind,
          parent ?? null,
          confidence,
        ]);
        const labelId = res.rows[0]?.tag;

        return text(
          `Tagged: ${label} (${kind}) -> document ${id}\n` + `label_id: ${labelId}  confidence: ${confidence}`,
        );
      });
    },
  };
}

export function createDocUntagTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_untag",
      description: "Remove a label from a document.",
      schema: z.object({
        id: z.string().describe("Document UUID"),
        label_id: z.number().describe("Label ID to remove"),
      }),
    },
    handler: async (args) => {
      const { id, label_id } = args as { id: string; label_id: number };

      return await withClient(async (client) => {
        await client.query(`SELECT docman.untag($1, $2)`, [id, label_id]);
        return text(`Untagged: label ${label_id} removed from document ${id}`);
      });
    },
  };
}
