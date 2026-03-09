import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createDocLinkTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_link",
      description:
        "Link an entity to a document. Creates the entity on-the-fly if it doesn't exist.\n" +
        "Resolves aliases: if the entity name matches an existing alias, uses the canonical entity.\n" +
        "Role describes the relationship: emetteur, destinataire, concerne, beneficiaire...",
      schema: z.object({
        id: z.string().describe("Document UUID"),
        kind: z.string().describe("Entity kind: client, fournisseur, projet, banque..."),
        name: z.string().describe("Entity name"),
        role: z.string().describe("Role: emetteur, destinataire, concerne, beneficiaire..."),
        confidence: z.number().optional().describe("Classification confidence 0.0-1.0 (default: 1.0)"),
      }),
    },
    handler: async (args) => {
      const { id, kind, name, role, confidence = 1.0 } = args as {
        id: string; kind: string; name: string; role: string; confidence?: number;
      };

      return await withClient(async (client) => {
        const res = await client.query(
          `SELECT docman.link($1, $2, $3, $4, $5)`,
          [id, kind, name, role, confidence]
        );
        const entityId = res.rows[0]?.link;

        return text(
          `Linked: ${name} (${kind}:${role}) -> document ${id}\n` +
          `entity_id: ${entityId}  confidence: ${confidence}`
        );
      });
    },
  };
}

export function createDocUnlinkTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_unlink",
      description: "Remove an entity link from a document.",
      schema: z.object({
        id: z.string().describe("Document UUID"),
        entity_id: z.number().describe("Entity ID to unlink"),
        role: z.string().describe("Role to remove"),
      }),
    },
    handler: async (args) => {
      const { id, entity_id, role } = args as { id: string; entity_id: number; role: string };

      return await withClient(async (client) => {
        await client.query(`SELECT docman.unlink($1, $2, $3)`, [id, entity_id, role]);
        return text(`Unlinked: entity ${entity_id} (${role}) removed from document ${id}`);
      });
    },
  };
}
