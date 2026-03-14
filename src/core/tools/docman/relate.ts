import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createDocRelateTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_relate",
      description:
        "Create a relation between two documents.\n" +
        "Kinds: follows, paid_by, supersedes, attached_to, references...",
      schema: z.object({
        source_id: z.string().describe("Source document UUID"),
        target_id: z.string().describe("Target document UUID"),
        kind: z.string().describe("Relation kind: follows, paid_by, supersedes, attached_to, references..."),
        confidence: z.number().optional().describe("Confidence 0.0-1.0 (default: 1.0)"),
      }),
    },
    handler: async (args) => {
      const {
        source_id,
        target_id,
        kind,
        confidence = 1.0,
      } = args as {
        source_id: string;
        target_id: string;
        kind: string;
        confidence?: number;
      };

      return await withClient(async (client) => {
        await client.query(`SELECT docman.relate($1, $2, $3, $4)`, [source_id, target_id, kind, confidence]);
        return text(`Related: ${source_id} --${kind}--> ${target_id}  confidence: ${confidence}`);
      });
    },
  };
}

export function createDocUnrelateTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_unrelate",
      description: "Remove a relation between two documents.",
      schema: z.object({
        source_id: z.string().describe("Source document UUID"),
        target_id: z.string().describe("Target document UUID"),
        kind: z.string().describe("Relation kind to remove"),
      }),
    },
    handler: async (args) => {
      const { source_id, target_id, kind } = args as {
        source_id: string;
        target_id: string;
        kind: string;
      };

      return await withClient(async (client) => {
        await client.query(`SELECT docman.unrelate($1, $2, $3)`, [source_id, target_id, kind]);
        return text(`Unrelated: ${source_id} --${kind}--> ${target_id} removed`);
      });
    },
  };
}

export function createDocRelationsTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_relations",
      description: "List all relations of a document (incoming and outgoing).",
      schema: z.object({
        id: z.string().describe("Document UUID"),
      }),
    },
    handler: async (args) => {
      const { id } = args as { id: string };

      return await withClient(async (client) => {
        const res = await client.query(`SELECT * FROM docman.relations($1)`, [id]);

        if (res.rows.length === 0) {
          return text(`No relations for document ${id}`);
        }

        const lines = res.rows.map(
          (r: any) =>
            `${r.direction} ${r.kind} -> ${r.related_file} (${r.related_id})  [${r.confidence}${r.assigned_by === "user" ? " user" : ""}]`,
        );
        return text(`Relations for ${id}:\n\n${lines.join("\n")}`);
      });
    },
  };
}
