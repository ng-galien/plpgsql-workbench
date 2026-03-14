/**
 * Align + Distribute tools — align elements, distribute with equal spacing or grid.
 * Uses loadCanvas to read element positions, computes deltas, batch updates.
 */

import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { loadCanvas } from "./state.js";
import type { Element, GroupElement, BBox } from "./types.js";

/** Simple bbox for an element (no font measurement — approximate for text) */
function bbox(el: Element): BBox {
  switch (el.type) {
    case "rect":
    case "image":
      return { x: el.x, y: el.y, w: el.width, h: el.height };
    case "text": {
      const w = (el.maxWidth ?? el.content.length * el.fontSize * 0.55);
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
      const children = (el as GroupElement).children;
      if (children.length === 0) return { x: 0, y: 0, w: 0, h: 0 };
      let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
      for (const child of children) {
        const b = bbox(child);
        minX = Math.min(minX, b.x);
        minY = Math.min(minY, b.y);
        maxX = Math.max(maxX, b.x + b.w);
        maxY = Math.max(maxY, b.y + b.h);
      }
      return { x: minX, y: minY, w: maxX - minX, h: maxY - minY };
    }
    default:
      return { x: 0, y: 0, w: 0, h: 0 };
  }
}

function findById(elements: Element[], idOrName: string): Element | undefined {
  for (const el of elements) {
    if (el.id === idOrName || el.name === idOrName) return el;
    if (el.type === "group") {
      const found = findById((el as GroupElement).children, idOrName);
      if (found) return found;
    }
  }
  return undefined;
}

export function createAlignTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_align",
      description: "Align multiple elements along an axis.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        ids: z.array(z.string()).describe("Element UUIDs or names (minimum 2)"),
        axis: z.enum(["left", "center_h", "right", "top", "center_v", "bottom"]).describe("Alignment axis"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const loaded = await loadCanvas(client, args.canvas_id as string);
        if (!loaded) return text("Canvas not found.");

        const ids = args.ids as string[];
        const elements = ids.map(id => findById(loaded.elements, id)).filter(Boolean) as Element[];
        if (elements.length < 2) return text("Need at least 2 elements.");

        const bboxes = elements.map(el => ({ el, bb: bbox(el) }));
        const axis = args.axis as string;
        const updates: { id: string; props: Record<string, number> }[] = [];

        let target: number;
        switch (axis) {
          case "left": target = Math.min(...bboxes.map(b => b.bb.x)); break;
          case "right": target = Math.max(...bboxes.map(b => b.bb.x + b.bb.w)); break;
          case "center_h": {
            const minX = Math.min(...bboxes.map(b => b.bb.x));
            const maxX = Math.max(...bboxes.map(b => b.bb.x + b.bb.w));
            target = (minX + maxX) / 2;
            break;
          }
          case "top": target = Math.min(...bboxes.map(b => b.bb.y)); break;
          case "bottom": target = Math.max(...bboxes.map(b => b.bb.y + b.bb.h)); break;
          case "center_v": {
            const minY = Math.min(...bboxes.map(b => b.bb.y));
            const maxY = Math.max(...bboxes.map(b => b.bb.y + b.bb.h));
            target = (minY + maxY) / 2;
            break;
          }
          default: return text(`Unknown axis: ${axis}`);
        }

        for (const { el, bb } of bboxes) {
          let dx = 0, dy = 0;
          switch (axis) {
            case "left": dx = target - bb.x; break;
            case "right": dx = target - (bb.x + bb.w); break;
            case "center_h": dx = target - (bb.x + bb.w / 2); break;
            case "top": dy = target - bb.y; break;
            case "bottom": dy = target - (bb.y + bb.h); break;
            case "center_v": dy = target - (bb.y + bb.h / 2); break;
          }
          if (Math.abs(dx) > 0.01 || Math.abs(dy) > 0.01) {
            const props: Record<string, number> = {};
            if (el.type === "line") {
              if (dx) { props.x1 = (el as any).x1 + dx; props.x2 = (el as any).x2 + dx; }
              if (dy) { props.y1 = (el as any).y1 + dy; props.y2 = (el as any).y2 + dy; }
            } else if (el.type === "circle" || el.type === "ellipse") {
              if (dx) props.cx = (el as any).cx + dx;
              if (dy) props.cy = (el as any).cy + dy;
            } else {
              if (dx) props.x = (el as any).x + dx;
              if (dy) props.y = (el as any).y + dy;
            }
            updates.push({ id: el.id, props });
          }
        }

        if (updates.length === 0) return text("All elements already aligned.");
        await client.query(
          `SELECT document.element_batch_update($1)`,
          [JSON.stringify(updates)],
        );
        return text(`Aligned ${elements.length} elements on ${axis} (${updates.length} moved)`);
      });
    },
  };
}

export function createDistributeTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_distribute",
      description: "Distribute elements with equal spacing on x or y axis.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        ids: z.array(z.string()).describe("Element UUIDs or names (minimum 3)"),
        axis: z.enum(["x", "y"]).describe("Distribution axis"),
        gap: z.number().optional().describe("Fixed gap in mm. If omitted, uniform distribution."),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const loaded = await loadCanvas(client, args.canvas_id as string);
        if (!loaded) return text("Canvas not found.");

        const ids = args.ids as string[];
        const elements = ids.map(id => findById(loaded.elements, id)).filter(Boolean) as Element[];
        if (elements.length < 3) return text("Need at least 3 elements.");

        const ax = args.axis as "x" | "y";
        const items = elements.map(el => ({ el, bb: bbox(el) }))
          .sort((a, b) => ax === "x" ? a.bb.x - b.bb.x : a.bb.y - b.bb.y);

        const first = items[0].bb;
        const last = items[items.length - 1].bb;
        const totalSize = items.reduce((s, i) => s + (ax === "x" ? i.bb.w : i.bb.h), 0);

        let gap: number;
        if (args.gap !== undefined) {
          gap = args.gap as number;
        } else {
          const extent = ax === "x"
            ? (last.x + last.w) - first.x
            : (last.y + last.h) - first.y;
          gap = (extent - totalSize) / (items.length - 1);
        }

        const updates: { id: string; props: Record<string, number> }[] = [];
        let pos = ax === "x" ? first.x : first.y;

        for (const { el, bb } of items) {
          const current = ax === "x" ? bb.x : bb.y;
          const delta = pos - current;
          if (Math.abs(delta) > 0.01) {
            const props: Record<string, number> = {};
            if (el.type === "line") {
              if (ax === "x") { props.x1 = (el as any).x1 + delta; props.x2 = (el as any).x2 + delta; }
              else { props.y1 = (el as any).y1 + delta; props.y2 = (el as any).y2 + delta; }
            } else if (el.type === "circle" || el.type === "ellipse") {
              props[ax === "x" ? "cx" : "cy"] = (el as any)[ax === "x" ? "cx" : "cy"] + delta;
            } else {
              props[ax] = (el as any)[ax] + delta;
            }
            updates.push({ id: el.id, props });
          }
          pos += (ax === "x" ? bb.w : bb.h) + gap;
        }

        if (updates.length === 0) return text("Elements already evenly distributed.");
        await client.query(
          `SELECT document.element_batch_update($1)`,
          [JSON.stringify(updates)],
        );
        return text(`Distributed ${items.length} elements on ${ax} (gap: ${gap.toFixed(1)}mm, ${updates.length} moved)`);
      });
    },
  };
}
