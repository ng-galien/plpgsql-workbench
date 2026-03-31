/**
 * ill_layout — Align + distribute + reorder + duplicate. Replaces align/distribute/reorder/element_duplicate.
 */

import { z } from "zod";
import { jsonb } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { loadCanvas } from "./state.js";
import type { BBox, Element, GroupElement } from "./types.js";

function bbox(el: Element): BBox {
  switch (el.type) {
    case "rect":
    case "image":
      return { x: el.x, y: el.y, w: el.width, h: el.height };
    case "text": {
      const w = el.maxWidth ?? el.content.length * el.fontSize * 0.55;
      const h = el.fontSize * 1.3;
      const bx = el.textAnchor === "middle" ? el.x - w / 2 : el.textAnchor === "end" ? el.x - w : el.x;
      return { x: bx, y: el.y - el.fontSize * 0.85, w, h };
    }
    case "line":
      return {
        x: Math.min(el.x1, el.x2),
        y: Math.min(el.y1, el.y2),
        w: Math.abs(el.x2 - el.x1) || 0.5,
        h: Math.abs(el.y2 - el.y1) || 0.5,
      };
    case "circle":
      return { x: el.cx - el.r, y: el.cy - el.r, w: el.r * 2, h: el.r * 2 };
    case "ellipse":
      return { x: el.cx - el.rx, y: el.cy - el.ry, w: el.rx * 2, h: el.ry * 2 };
    case "group": {
      const ch = (el as GroupElement).children;
      if (ch.length === 0) return { x: 0, y: 0, w: 0, h: 0 };
      let mnX = Infinity,
        mnY = Infinity,
        mxX = -Infinity,
        mxY = -Infinity;
      for (const c of ch) {
        const b = bbox(c);
        mnX = Math.min(mnX, b.x);
        mnY = Math.min(mnY, b.y);
        mxX = Math.max(mxX, b.x + b.w);
        mxY = Math.max(mxY, b.y + b.h);
      }
      return { x: mnX, y: mnY, w: mxX - mnX, h: mxY - mnY };
    }
    default:
      return { x: 0, y: 0, w: 0, h: 0 };
  }
}

function findById(elements: Element[], idOrName: string): Element | undefined {
  for (const el of elements) {
    if (el.id === idOrName || el.name === idOrName) return el;
    if (el.type === "group") {
      const f = findById((el as GroupElement).children, idOrName);
      if (f) return f;
    }
  }
  return undefined;
}

export function createIllLayoutTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_layout",
      description: `Layout operations on elements.

Actions:
- align: Align elements. Args: ids (array), axis (left|center_h|right|top|center_v|bottom)
- distribute: Distribute evenly. Args: ids (array), axis (x|y), gap (optional fixed gap mm)
- reorder: Change z-order. Args: id, direction (to_front|to_back|forward|backward)
- duplicate: Clone element with offset. Args: id, offset_x (default 5), offset_y (default 5)
- move: Move element(s) by offset. Args: id, dx, dy`,
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        action: z.enum(["align", "distribute", "reorder", "duplicate", "move"]).describe("Layout action"),
        ids: z.array(z.string()).optional().describe("Element names/UUIDs (align, distribute)"),
        id: z.string().optional().describe("Element name/UUID (reorder, duplicate, move)"),
        axis: z.string().optional().describe("Align: left|center_h|right|top|center_v|bottom. Distribute: x|y"),
        direction: z.string().optional().describe("Reorder direction"),
        gap: z.number().optional().describe("Distribute: fixed gap mm"),
        offset_x: z.number().optional().describe("Duplicate/move: X offset mm"),
        offset_y: z.number().optional().describe("Duplicate/move: Y offset mm"),
      }),
    },
    handler: async (args, _extra) => {
      const canvasId = args.canvas_id as string;
      const action = args.action as string;

      return withClient(async (client) => {
        switch (action) {
          case "align": {
            const ids = args.ids as string[];
            if (!ids || ids.length < 2) return text("Need at least 2 IDs.");
            const loaded = await loadCanvas(client, canvasId);
            if (!loaded) return text("Canvas not found.");
            const elements = ids.map((id) => findById(loaded.elements, id)).filter(Boolean) as Element[];
            if (elements.length < 2) return text("Could not resolve at least 2 elements.");

            const bboxes = elements.map((el) => ({ el, bb: bbox(el) }));
            const ax = args.axis as string;
            let target: number;
            switch (ax) {
              case "left":
                target = Math.min(...bboxes.map((b) => b.bb.x));
                break;
              case "right":
                target = Math.max(...bboxes.map((b) => b.bb.x + b.bb.w));
                break;
              case "center_h": {
                const mn = Math.min(...bboxes.map((b) => b.bb.x));
                const mx = Math.max(...bboxes.map((b) => b.bb.x + b.bb.w));
                target = (mn + mx) / 2;
                break;
              }
              case "top":
                target = Math.min(...bboxes.map((b) => b.bb.y));
                break;
              case "bottom":
                target = Math.max(...bboxes.map((b) => b.bb.y + b.bb.h));
                break;
              case "center_v": {
                const mn = Math.min(...bboxes.map((b) => b.bb.y));
                const mx = Math.max(...bboxes.map((b) => b.bb.y + b.bb.h));
                target = (mn + mx) / 2;
                break;
              }
              default:
                return text(`Unknown axis: ${ax}`);
            }

            const updates: { id: string; props: Record<string, number> }[] = [];
            for (const { el, bb } of bboxes) {
              let dx = 0,
                dy = 0;
              if (ax === "left") dx = target - bb.x;
              else if (ax === "right") dx = target - (bb.x + bb.w);
              else if (ax === "center_h") dx = target - (bb.x + bb.w / 2);
              else if (ax === "top") dy = target - bb.y;
              else if (ax === "bottom") dy = target - (bb.y + bb.h);
              else if (ax === "center_v") dy = target - (bb.y + bb.h / 2);
              if (Math.abs(dx) > 0.01 || Math.abs(dy) > 0.01) {
                const p: Record<string, number> = {};
                if (el.type === "line") {
                  if (dx) {
                    p.x1 = (el as any).x1 + dx;
                    p.x2 = (el as any).x2 + dx;
                  }
                  if (dy) {
                    p.y1 = (el as any).y1 + dy;
                    p.y2 = (el as any).y2 + dy;
                  }
                } else if (el.type === "circle" || el.type === "ellipse") {
                  if (dx) p.cx = (el as any).cx + dx;
                  if (dy) p.cy = (el as any).cy + dy;
                } else {
                  if (dx) p.x = (el as any).x + dx;
                  if (dy) p.y = (el as any).y + dy;
                }
                updates.push({ id: el.id, props: p });
              }
            }
            if (updates.length === 0) return text("Already aligned.");
            await client.query(`SELECT document.element_batch_update($1)`, [jsonb(updates)]);
            return text(`Aligned ${elements.length} on ${ax} (${updates.length} moved)`);
          }

          case "distribute": {
            const ids = args.ids as string[];
            if (!ids || ids.length < 3) return text("Need at least 3 IDs.");
            const loaded = await loadCanvas(client, canvasId);
            if (!loaded) return text("Canvas not found.");
            const elements = ids.map((id) => findById(loaded.elements, id)).filter(Boolean) as Element[];
            const ax = (args.axis as "x" | "y") ?? "y";
            const items = elements
              .map((el) => ({ el, bb: bbox(el) }))
              .sort((a, b) => (ax === "x" ? a.bb.x - b.bb.x : a.bb.y - b.bb.y));
            const first = items[0]!.bb;
            const last = items[items.length - 1]!.bb;
            const totalSize = items.reduce((s, i) => s + (ax === "x" ? i.bb.w : i.bb.h), 0);
            const fixedGap = args.gap as number | undefined;
            const gap =
              fixedGap ??
              ((ax === "x" ? last.x + last.w - first.x : last.y + last.h - first.y) - totalSize) / (items.length - 1);

            const updates: { id: string; props: Record<string, number> }[] = [];
            let pos = ax === "x" ? first.x : first.y;
            for (const { el, bb } of items) {
              const cur = ax === "x" ? bb.x : bb.y;
              const delta = pos - cur;
              if (Math.abs(delta) > 0.01) {
                const p: Record<string, number> = {};
                if (el.type === "line") {
                  if (ax === "x") {
                    p.x1 = (el as any).x1 + delta;
                    p.x2 = (el as any).x2 + delta;
                  } else {
                    p.y1 = (el as any).y1 + delta;
                    p.y2 = (el as any).y2 + delta;
                  }
                } else if (el.type === "circle" || el.type === "ellipse") {
                  p[ax === "x" ? "cx" : "cy"] = (el as any)[ax === "x" ? "cx" : "cy"] + delta;
                } else {
                  p[ax] = (el as any)[ax] + delta;
                }
                updates.push({ id: el.id, props: p });
              }
              pos += (ax === "x" ? bb.w : bb.h) + gap;
            }
            if (updates.length === 0) return text("Already distributed.");
            await client.query(`SELECT document.element_batch_update($1)`, [jsonb(updates)]);
            return text(`Distributed ${items.length} on ${ax} (gap: ${gap.toFixed(1)}mm)`);
          }

          case "reorder": {
            if (!args.id || !args.direction) return text("id and direction required");
            const { rows } = await client.query(
              `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) LIMIT 1`,
              [canvasId, args.id],
            );
            if (rows.length === 0) return text(`Not found: ${args.id}`);
            await client.query(`SELECT document.element_reorder($1, $2)`, [rows[0].id, args.direction]);
            return text(`Reordered ${String(rows[0].id).slice(0, 8)} -> ${args.direction}`);
          }

          case "duplicate": {
            if (!args.id) return text("id required");
            const { rows } = await client.query(
              `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) LIMIT 1`,
              [canvasId, args.id],
            );
            if (rows.length === 0) return text(`Not found: ${args.id}`);
            const dx = args.offset_x ?? 5;
            const dy = args.offset_y ?? 5;
            const { rows: r2 } = await client.query(`SELECT document.element_duplicate($1, $2, $3) as id`, [
              rows[0].id,
              dx,
              dy,
            ]);
            return text(`Duplicated -> ${String(r2[0]?.id).slice(0, 8)} (+${dx},+${dy}mm)`);
          }

          case "move": {
            if (!args.id) return text("id required");
            const { rows } = await client.query(
              `SELECT id FROM document.element WHERE canvas_id = $1 AND (id::text = $2 OR name = $2) LIMIT 1`,
              [canvasId, args.id],
            );
            if (rows.length === 0) return text(`Not found: ${args.id}`);
            const { rows: r2 } = await client.query(`SELECT document.element_move($1, $2, $3) as count`, [
              rows[0].id,
              args.offset_x ?? 0,
              args.offset_y ?? 0,
            ]);
            return text(`Moved ${r2[0]?.count ?? 0} element(s)`);
          }

          default:
            return text(`Unknown action: ${action}`);
        }
      });
    },
  };
}
