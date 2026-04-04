/**
 * ill_group — Group operations. Replaces group_elements/ungroup/add_to_group/remove_from_group.
 */

import { z } from "zod";
import type { ToolHandler, WithClient } from "../../core/container.js";
import { text } from "../../core/helpers.js";

function resolveElement(client: any, canvasId: string, idOrName: string) {
  return client.query(`SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) LIMIT 1`, [
    canvasId,
    idOrName,
  ]);
}

export function createIllGroupTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_group",
      description: `Group operations on elements.

Actions:
- create: Group elements together. Args: ids (array of names/UUIDs, min 2), name (optional group name)
- dissolve: Ungroup — children move to parent level. Args: id (group name/UUID)
- add: Move element into a group. Args: element_id, group_id
- remove: Remove element from group to top level. Args: element_id`,
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        action: z.enum(["create", "dissolve", "add", "remove"]).describe("Group action"),
        ids: z.array(z.string()).optional().describe("Element names/UUIDs to group (create)"),
        id: z.string().optional().describe("Group name/UUID (dissolve)"),
        name: z.string().optional().describe("Group name (create)"),
        element_id: z.string().optional().describe("Element to move (add, remove)"),
        group_id: z.string().optional().describe("Target group (add)"),
      }),
    },
    handler: async (args, _extra) => {
      const canvasId = args.canvas_id as string;
      const action = args.action as string;

      return withClient(async (client) => {
        switch (action) {
          case "create": {
            const ids = args.ids as string[];
            if (!ids || ids.length < 2) return text("Need at least 2 element IDs.");
            const uuids: string[] = [];
            for (const idOrName of ids) {
              const { rows } = await resolveElement(client, canvasId, idOrName);
              if (rows.length > 0) uuids.push(rows[0].id);
            }
            if (uuids.length < 2) return text("Could not resolve at least 2 elements.");
            const { rows } = await client.query(`SELECT document.group_create($1, $2, $3) as id`, [
              canvasId,
              uuids,
              args.name ?? null,
            ]);
            return text(
              `Grouped ${uuids.length} elements -> ${String(rows[0]?.id).slice(0, 8)}${args.name ? ` (${args.name})` : ""}`,
            );
          }

          case "dissolve": {
            if (!args.id) return text("id is required");
            const { rows: resolved } = await client.query(
              `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) AND type = 'group' LIMIT 1`,
              [canvasId, args.id],
            );
            if (resolved.length === 0) return text(`Group not found: ${args.id}`);
            const { rows } = await client.query(`SELECT document.group_dissolve($1) as count`, [resolved[0].id]);
            return text(`Ungrouped: ${rows[0]?.count ?? 0} children released`);
          }

          case "add": {
            if (!args.element_id || !args.group_id) return text("element_id and group_id required");
            const { rows: elRows } = await resolveElement(client, canvasId, args.element_id as string);
            const { rows: grpRows } = await client.query(
              `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) AND type = 'group' LIMIT 1`,
              [canvasId, args.group_id],
            );
            if (elRows.length === 0) return text(`Element not found: ${args.element_id}`);
            if (grpRows.length === 0) return text(`Group not found: ${args.group_id}`);
            await client.query(`SELECT document.group_add_member($1, $2)`, [grpRows[0].id, elRows[0].id]);
            return text(`Moved ${String(elRows[0].id).slice(0, 8)} into group`);
          }

          case "remove": {
            if (!args.element_id) return text("element_id required");
            const { rows } = await resolveElement(client, canvasId, args.element_id as string);
            if (rows.length === 0) return text(`Element not found: ${args.element_id}`);
            await client.query(`SELECT document.group_remove_member($1)`, [rows[0].id]);
            return text(`Removed ${String(rows[0].id).slice(0, 8)} from group -> top level`);
          }

          default:
            return text(`Unknown action: ${action}`);
        }
      });
    },
  };
}
