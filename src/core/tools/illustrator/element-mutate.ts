/**
 * Element mutation tools — update, delete, duplicate, reorder, clear, batch_update, batch_add
 */

import { z } from "zod";
import type { ToolHandler, ToolExtra, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createUpdateElementTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_update_element",
      description: "Update properties of an existing element. Pass only changed properties.",
      schema: z.object({
        element_id: z.string().describe("Element UUID or name"),
        canvas_id: z.string().describe("Canvas UUID"),
        props: z.record(z.string(), z.unknown()).describe("Properties to update (merged, not replaced)"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        // Resolve by name if not UUID
        const { rows: resolved } = await client.query(
          `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) LIMIT 1`,
          [args.canvas_id, args.element_id],
        );
        if (resolved.length === 0) return text(`Element not found: ${args.element_id}`);
        const eid = resolved[0].id;

        await client.query(
          `SELECT document.element_update($1, $2)`,
          [eid, JSON.stringify(args.props)],
        );
        return text(`Updated ${String(eid).slice(0, 8)}`);
      });
    },
  };
}

export function createDeleteElementTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_delete_element",
      description: "Remove an element. If it's a group, all children are deleted too.",
      schema: z.object({
        element_id: z.string().describe("Element UUID or name"),
        canvas_id: z.string().describe("Canvas UUID"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows: resolved } = await client.query(
          `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) LIMIT 1`,
          [args.canvas_id, args.element_id],
        );
        if (resolved.length === 0) return text(`Element not found: ${args.element_id}`);

        const { rows } = await client.query(
          `SELECT document.element_delete($1) as result`,
          [resolved[0].id],
        );
        const r = rows[0]?.result;
        return text(`Deleted ${r?.type ?? "element"} "${r?.name ?? r?.id}"`);
      });
    },
  };
}

export function createElementDuplicateTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_element_duplicate",
      description: "Duplicate an element with an offset. Works on groups (deep clone).",
      schema: z.object({
        element_id: z.string().describe("Element UUID or name"),
        canvas_id: z.string().describe("Canvas UUID"),
        offset_x: z.number().optional().describe("Horizontal offset in mm. Default: 5"),
        offset_y: z.number().optional().describe("Vertical offset in mm. Default: 5"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows: resolved } = await client.query(
          `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) LIMIT 1`,
          [args.canvas_id, args.element_id],
        );
        if (resolved.length === 0) return text(`Element not found: ${args.element_id}`);

        const { rows } = await client.query(
          `SELECT document.element_duplicate($1, $2, $3) as id`,
          [resolved[0].id, args.offset_x ?? 5, args.offset_y ?? 5],
        );
        return text(`Duplicated -> ${String(rows[0]?.id).slice(0, 8)} (offset +${args.offset_x ?? 5},+${args.offset_y ?? 5}mm)`);
      });
    },
  };
}

export function createReorderElementTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_reorder_element",
      description: "Change z-order of an element.",
      schema: z.object({
        element_id: z.string().describe("Element UUID or name"),
        canvas_id: z.string().describe("Canvas UUID"),
        action: z.enum(["to_front", "to_back", "forward", "backward"]).describe("Reorder action"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows: resolved } = await client.query(
          `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) LIMIT 1`,
          [args.canvas_id, args.element_id],
        );
        if (resolved.length === 0) return text(`Element not found: ${args.element_id}`);

        await client.query(
          `SELECT document.element_reorder($1, $2)`,
          [resolved[0].id, args.action],
        );
        return text(`Reordered ${String(resolved[0].id).slice(0, 8)} -> ${args.action}`);
      });
    },
  };
}

export function createClearCanvasTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_clear_canvas",
      description: "Remove all elements from a canvas. Keeps canvas settings.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows } = await client.query(
          `SELECT document.canvas_clear($1) as count`,
          [args.canvas_id],
        );
        return text(`Canvas cleared (${rows[0]?.count ?? 0} elements removed)`);
      });
    },
  };
}

export function createBatchUpdateTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_batch_update",
      description: "Update multiple elements at once. Single transaction.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        updates: z.array(z.object({
          id: z.string().describe("Element UUID or name"),
          props: z.record(z.string(), z.unknown()).describe("Properties to update"),
        })).describe("Array of {id, props} updates"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        // Resolve names to IDs
        const resolved: { id: string; props: unknown }[] = [];
        for (const u of args.updates as any[]) {
          const { rows } = await client.query(
            `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) LIMIT 1`,
            [args.canvas_id, u.id],
          );
          if (rows.length > 0) resolved.push({ id: rows[0].id, props: u.props });
        }
        if (resolved.length === 0) return text("No elements found to update.");

        const { rows } = await client.query(
          `SELECT document.element_batch_update($1) as count`,
          [JSON.stringify(resolved)],
        );
        return text(`Batch updated ${rows[0]?.count ?? 0}/${(args.updates as any[]).length} elements`);
      });
    },
  };
}

export function createBatchAddTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_batch_add",
      description: "Add multiple elements in one call. Each needs a 'type' field plus type-specific properties. Elements added in order.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        elements: z.array(z.record(z.string(), z.unknown())).describe("Array of element definitions with 'type' field"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const ids: string[] = [];
        for (const el of args.elements as any[]) {
          const type = el.type;
          if (!type) continue;
          const { rows } = await client.query(
            `SELECT document.element_add($1, $2, 0, $3) as id`,
            [args.canvas_id, type, JSON.stringify(el)],
          );
          if (rows[0]?.id) ids.push(rows[0].id);
        }
        return text(`Batch added ${ids.length} elements:\n${ids.map((id, i) => `  ${i + 1}. ${String(id).slice(0, 8)}`).join("\n")}`);
      });
    },
  };
}
