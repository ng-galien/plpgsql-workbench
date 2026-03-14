/**
 * ill_add — Add any element to a canvas.
 * Single tool replaces add_text, add_rect, add_line, add_image, add_circle, add_ellipse, add_path.
 */

import { z } from "zod";
import { jsonb } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createIllAddTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_add",
      description: `Add an element to a canvas. All coordinates in mm.

Types and their key properties:
- text: x, y, content, fontSize (mm, ~12 titles, ~6 subtitles, ~4 body), fontFamily, fontWeight, fontStyle, fill, textAnchor (start|middle|end), maxWidth (word-wrap)
- rect: x, y, width, height, fill, stroke, strokeWidth, rx (border radius)
- line: x1, y1, x2, y2, stroke, strokeWidth
- image: x, y, width, height, asset_id (from ill_list_assets), objectFit (cover|contain|fill), cropX/cropY (0-1), cropZoom (>=1)
- circle: cx, cy, r, fill, stroke
- ellipse: cx, cy, rx, ry, fill, stroke
- path: d (SVG path data), fill, stroke

Common: name (semantic label), opacity (0-1), rotation (degrees), fill, stroke, strokeWidth`,
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        type: z.enum(["text", "rect", "line", "image", "circle", "ellipse", "path"]).describe("Element type"),
        props: z.record(z.string(), z.unknown()).describe("Type-specific properties (see tool description)"),
      }),
    },
    handler: async (args, _extra) => {
      const canvasId = args.canvas_id as string;
      const type = args.type as string;
      const props = args.props as Record<string, unknown>;

      // For images, fetch asset dimensions for crop math
      if (type === "image" && props.asset_id) {
        const assetResult = await withClient(async (client) => {
          const { rows } = await client.query(`SELECT width, height, filename FROM asset.asset WHERE id = $1`, [
            props.asset_id as string,
          ]);
          return rows[0];
        });
        if (assetResult) {
          if (!props.naturalWidth) props.naturalWidth = assetResult.width;
          if (!props.naturalHeight) props.naturalHeight = assetResult.height;
        }
      }

      return withClient(async (client) => {
        const { rows } = await client.query(`SELECT document.element_add($1, $2, 0, $3) as id`, [
          canvasId,
          type,
          jsonb(props),
        ]);
        const id = rows[0]?.id;
        const shortId = String(id).slice(0, 8);
        const name = props.name ? ` (${props.name})` : "";

        switch (type) {
          case "text":
            return text(
              `Text "${String(props.content ?? "").slice(0, 30)}"${name} -> ${shortId} at x:${props.x} y:${props.y}`,
            );
          case "rect":
            return text(`Rect${name} -> ${shortId} at x:${props.x} y:${props.y} ${props.width}×${props.height}mm`);
          case "line":
            return text(`Line${name} -> ${shortId} (${props.x1},${props.y1}) -> (${props.x2},${props.y2})`);
          case "image":
            return text(`Image${name} -> ${shortId} at x:${props.x} y:${props.y} ${props.width}×${props.height}mm`);
          case "circle":
            return text(`Circle${name} -> ${shortId} cx:${props.cx} cy:${props.cy} r:${props.r}`);
          case "ellipse":
            return text(`Ellipse${name} -> ${shortId} cx:${props.cx} cy:${props.cy} rx:${props.rx} ry:${props.ry}`);
          case "path":
            return text(`Path${name} -> ${shortId}`);
          default:
            return text(`${type}${name} -> ${shortId}`);
        }
      });
    },
  };
}
