/**
 * add_image — Add an image element to a canvas.
 */

import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createAddImageTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_add_image",
      description: "Add an image to a canvas. Reference an asset by ID. Supports crop (cover/contain/fill), filters, border, shadow.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        asset_id: z.string().describe("Asset UUID from asset.asset"),
        x: z.number().describe("X position in mm"),
        y: z.number().describe("Y position in mm"),
        width: z.number().describe("Frame width in mm"),
        height: z.number().describe("Frame height in mm"),
        name: z.string().optional().describe("Semantic name"),
        objectFit: z.enum(["cover", "contain", "fill"]).optional().describe("Fit mode. Default: cover"),
        cropX: z.number().optional().describe("Horizontal pan 0-1. Default: 0.5 (centered)"),
        cropY: z.number().optional().describe("Vertical pan 0-1. Default: 0.5 (centered)"),
        cropZoom: z.number().optional().describe("Zoom level >=1. Default: 1"),
        opacity: z.number().optional().describe("Opacity 0-1. Default: 1"),
        rotation: z.number().optional().describe("Rotation degrees. Default: 0"),
        borderWidth: z.number().optional().describe("Border width mm. Default: 0"),
        borderColor: z.string().optional().describe("Border color. Default: #000000"),
        borderRadius: z.number().optional().describe("Border radius mm. Default: 0"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        // Get asset dimensions for crop math
        const { rows: assetRows } = await client.query(
          `SELECT width, height, filename FROM asset.asset WHERE id = $1`,
          [args.asset_id],
        );
        const asset = assetRows[0];

        const props: Record<string, unknown> = {
          x: args.x, y: args.y, width: args.width, height: args.height,
          name: args.name ?? null,
          asset_id: args.asset_id,
          objectFit: args.objectFit ?? "cover",
          cropX: args.cropX ?? 0.5,
          cropY: args.cropY ?? 0.5,
          cropZoom: args.cropZoom ?? 1,
          opacity: args.opacity ?? 1,
          rotation: args.rotation ?? 0,
          borderWidth: args.borderWidth ?? 0,
          borderColor: args.borderColor ?? "#000000",
          borderRadius: args.borderRadius ?? 0,
          naturalWidth: asset?.width ?? null,
          naturalHeight: asset?.height ?? null,
        };

        const { rows } = await client.query(
          `SELECT document.element_add($1, 'image', 0, $2) as id`,
          [args.canvas_id, JSON.stringify(props)],
        );
        const id = rows[0]?.id;
        return text(`Image "${asset?.filename ?? "?"}" -> ${String(id).slice(0, 8)} at x:${args.x} y:${args.y} ${args.width}×${args.height}mm`);
      });
    },
  };
}
