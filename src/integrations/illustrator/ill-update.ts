/**
 * ill_update — Update one or multiple elements. Replaces update_element + batch_update.
 * ill_delete — Delete one or multiple elements.
 * ill_batch — Mixed operations (add + update + delete) in one call.
 */

import { z } from "zod";
import { jsonb } from "../../core/connection.js";
import type { ToolHandler, WithClient } from "../../core/container.js";
import { text } from "../../core/helpers.js";

function resolveElement(client: any, canvasId: string, idOrName: string) {
  return client.query(`SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) LIMIT 1`, [
    canvasId,
    idOrName,
  ]);
}

export function createIllUpdateTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_update",
      description: "Update element(s). Pass a single {id, props} or an array for batch update.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        updates: z
          .union([
            z.object({
              id: z.string().describe("Element UUID or name"),
              props: z.record(z.string(), z.unknown()).describe("Properties to merge"),
            }),
            z.array(
              z.object({
                id: z.string().describe("Element UUID or name"),
                props: z.record(z.string(), z.unknown()).describe("Properties to merge"),
              }),
            ),
          ])
          .describe("Single update or array of updates"),
      }),
    },
    handler: async (args, _extra) => {
      const canvasId = args.canvas_id as string;
      const raw = args.updates;
      const updates = Array.isArray(raw) ? raw : [raw];

      return withClient(async (client) => {
        let count = 0;
        for (const u of updates as any[]) {
          const { rows } = await resolveElement(client, canvasId, u.id);
          if (rows.length === 0) continue;
          await client.query(`SELECT document.element_update($1, $2)`, [rows[0].id, jsonb(u.props)]);
          count++;
        }
        return text(`Updated ${count}/${updates.length} element(s)`);
      });
    },
  };
}

export function createIllDeleteTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_delete",
      description: "Delete element(s). Pass a single ID/name or array. Groups cascade to children.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        ids: z
          .union([
            z.string().describe("Element UUID or name"),
            z.array(z.string()).describe("Array of element UUIDs or names"),
          ])
          .describe("Element(s) to delete"),
      }),
    },
    handler: async (args, _extra) => {
      const canvasId = args.canvas_id as string;
      const raw = args.ids;
      const ids = Array.isArray(raw) ? raw : [raw];

      return withClient(async (client) => {
        let count = 0;
        for (const idOrName of ids as string[]) {
          const { rows } = await resolveElement(client, canvasId, idOrName);
          if (rows.length === 0) continue;
          await client.query(`SELECT document.element_delete($1)`, [rows[0].id]);
          count++;
        }
        return text(`Deleted ${count}/${ids.length} element(s)`);
      });
    },
  };
}

export function createIllBatchTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_batch",
      description: `Execute mixed operations in one call. Each op has an "action" field.

Actions:
- add: { action: "add", type: "text"|"rect"|..., props: {...} }
- update: { action: "update", id: "name-or-uuid", props: {...} }
- delete: { action: "delete", id: "name-or-uuid" }

Operations execute in order — later ops can reference elements added earlier by name.`,
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        ops: z.array(z.record(z.string(), z.unknown())).describe("Array of operations"),
      }),
    },
    handler: async (args, _extra) => {
      const canvasId = args.canvas_id as string;
      const ops = args.ops as any[];
      const results: string[] = [];

      return withClient(async (client) => {
        for (const op of ops) {
          switch (op.action) {
            case "add": {
              const { rows } = await client.query(`SELECT document.element_add($1, $2, 0, $3) as id`, [
                canvasId,
                op.type,
                jsonb(op.props ?? {}),
              ]);
              results.push(`+ ${op.type} ${op.props?.name ?? rows[0]?.id?.slice(0, 8)}`);
              break;
            }
            case "update": {
              const { rows } = await resolveElement(client, canvasId, op.id);
              if (rows.length > 0) {
                await client.query(`SELECT document.element_update($1, $2)`, [rows[0].id, jsonb(op.props ?? {})]);
                results.push(`~ ${op.id}`);
              } else {
                results.push(`? ${op.id} (not found)`);
              }
              break;
            }
            case "delete": {
              const { rows } = await resolveElement(client, canvasId, op.id);
              if (rows.length > 0) {
                await client.query(`SELECT document.element_delete($1)`, [rows[0].id]);
                results.push(`- ${op.id}`);
              } else {
                results.push(`? ${op.id} (not found)`);
              }
              break;
            }
            default:
              results.push(`? unknown action: ${op.action}`);
          }
        }
        return text(`Batch: ${ops.length} ops\n${results.join("\n")}`);
      });
    },
  };
}
