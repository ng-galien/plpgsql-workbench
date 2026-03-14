import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createDocLabelsTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_labels",
      description: "List labels (taxonomy). Filter by kind or parent. Includes aliases.",
      schema: z.object({
        kind: z.enum(["category", "tag"]).optional().describe("Filter by kind"),
        parent_id: z.number().optional().describe("Filter by parent label ID"),
      }),
    },
    handler: async (args) => {
      const { kind, parent_id } = args as { kind?: string; parent_id?: number };

      return await withClient(async (client) => {
        const res = await client.query(`SELECT * FROM docman.labels($1, $2)`, [kind ?? null, parent_id ?? null]);

        if (res.rows.length === 0) {
          return text("No labels defined yet.");
        }

        const lines = res.rows.map((r: any) => {
          const aliases = r.aliases?.length > 0 ? ` aliases: ${r.aliases.join(", ")}` : "";
          const parent = r.parent_id ? ` parent: ${r.parent_id}` : "";
          return `[${r.id}] ${r.name} (${r.kind})${parent}${aliases}`;
        });
        return text(`Labels (${res.rows.length}):\n\n${lines.join("\n")}`);
      });
    },
  };
}

export function createDocEntitiesTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_entities",
      description: "List entities (business actors). Filter by kind. Includes aliases.",
      schema: z.object({
        kind: z.string().optional().describe("Filter by entity kind (client, fournisseur, projet...)"),
      }),
    },
    handler: async (args) => {
      const { kind } = args as { kind?: string };

      return await withClient(async (client) => {
        const res = await client.query(`SELECT * FROM docman.entities($1)`, [kind ?? null]);

        if (res.rows.length === 0) {
          return text(kind ? `No entities of kind '${kind}'.` : "No entities defined yet.");
        }

        const lines = res.rows.map((r: any) => {
          const aliases = r.aliases?.length > 0 ? ` aliases: ${r.aliases.join(", ")}` : "";
          const meta = Object.keys(r.metadata ?? {}).length > 0 ? ` ${JSON.stringify(r.metadata)}` : "";
          return `[${r.id}] ${r.name} (${r.kind})${aliases}${meta}`;
        });
        return text(`Entities (${res.rows.length}):\n\n${lines.join("\n")}`);
      });
    },
  };
}

export function createDocEntityKindsTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_entity_kinds",
      description: "List existing entity kinds with counts.",
      schema: z.object({}),
    },
    handler: async () => {
      return await withClient(async (client) => {
        const res = await client.query(`SELECT * FROM docman.entity_kinds()`);

        if (res.rows.length === 0) {
          return text("No entity kinds defined yet.");
        }

        const lines = res.rows.map((r: any) => `${r.kind}: ${r.count}`);
        return text(`Entity kinds:\n\n${lines.join("\n")}`);
      });
    },
  };
}

export function createDocDocTypesTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "doc_doc_types",
      description: "List document types in use with counts.",
      schema: z.object({}),
    },
    handler: async () => {
      return await withClient(async (client) => {
        const res = await client.query(`SELECT * FROM docman.doc_types()`);

        if (res.rows.length === 0) {
          return text("No document types assigned yet.");
        }

        const lines = res.rows.map((r: any) => `${r.doc_type}: ${r.count}`);
        return text(`Document types:\n\n${lines.join("\n")}`);
      });
    },
  };
}
