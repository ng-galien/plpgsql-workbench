/**
 * Group tools — group_elements, ungroup, add_to_group, remove_from_group
 */

import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createGroupElementsTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_group_elements",
      description: "Group existing elements into a nested group. All elements must be siblings.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        ids: z.array(z.string()).describe("Element UUIDs or names to group (minimum 2)"),
        name: z.string().optional().describe("Semantic name for the group"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        // Resolve names to UUIDs
        const uuids: string[] = [];
        for (const idOrName of args.ids as string[]) {
          const { rows } = await client.query(
            `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) LIMIT 1`,
            [args.canvas_id, idOrName],
          );
          if (rows.length > 0) uuids.push(rows[0].id);
        }
        if (uuids.length < 2) return text("Need at least 2 elements to group.");

        const { rows } = await client.query(
          `SELECT document.group_create($1, $2, $3) as id`,
          [args.canvas_id, uuids, args.name ?? null],
        );
        return text(`Grouped ${uuids.length} elements -> ${String(rows[0]?.id).slice(0, 8)}${args.name ? ` (${args.name})` : ""}`);
      });
    },
  };
}

export function createUngroupTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_ungroup",
      description: "Dissolve a group. Children move to the group's parent level.",
      schema: z.object({
        element_id: z.string().describe("Group UUID or name"),
        canvas_id: z.string().describe("Canvas UUID"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows: resolved } = await client.query(
          `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) AND type = 'group' LIMIT 1`,
          [args.canvas_id, args.element_id],
        );
        if (resolved.length === 0) return text(`Group not found: ${args.element_id}`);

        const { rows } = await client.query(
          `SELECT document.group_dissolve($1) as count`,
          [resolved[0].id],
        );
        return text(`Ungrouped: ${rows[0]?.count ?? 0} children released`);
      });
    },
  };
}

export function createAddToGroupTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_add_to_group",
      description: "Move an existing element into a group.",
      schema: z.object({
        element_id: z.string().describe("Element UUID or name to move"),
        group_id: z.string().describe("Target group UUID or name"),
        canvas_id: z.string().describe("Canvas UUID"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows: elRows } = await client.query(
          `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) LIMIT 1`,
          [args.canvas_id, args.element_id],
        );
        const { rows: grpRows } = await client.query(
          `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) AND type = 'group' LIMIT 1`,
          [args.canvas_id, args.group_id],
        );
        if (elRows.length === 0) return text(`Element not found: ${args.element_id}`);
        if (grpRows.length === 0) return text(`Group not found: ${args.group_id}`);

        await client.query(`SELECT document.group_add_member($1, $2)`, [grpRows[0].id, elRows[0].id]);
        return text(`Moved ${String(elRows[0].id).slice(0, 8)} into group ${String(grpRows[0].id).slice(0, 8)}`);
      });
    },
  };
}

export function createRemoveFromGroupTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_remove_from_group",
      description: "Remove an element from its group, move to top level.",
      schema: z.object({
        element_id: z.string().describe("Element UUID or name"),
        canvas_id: z.string().describe("Canvas UUID"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows } = await client.query(
          `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) LIMIT 1`,
          [args.canvas_id, args.element_id],
        );
        if (rows.length === 0) return text(`Element not found: ${args.element_id}`);

        await client.query(`SELECT document.group_remove_member($1)`, [rows[0].id]);
        return text(`Removed ${String(rows[0].id).slice(0, 8)} from group -> top level`);
      });
    },
  };
}
