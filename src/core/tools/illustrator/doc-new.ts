/**
 * doc_new — Create a new blank canvas document.
 */

import { z } from "zod";
import type { ToolHandler, ToolExtra, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { FORMATS, SCREEN_FORMATS } from "./types.js";

export function createDocNewTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_doc_new",
      description: "Create a new blank document (canvas). Sets format, orientation, background color. Coordinates are in mm.",
      schema: z.object({
        name: z.string().describe("Document name"),
        format: z.enum(["A2", "A3", "A4", "A5", "HD", "MACBOOK", "IPAD", "MOBILE"]).optional().describe("Canvas format. Default: A4"),
        orientation: z.enum(["portrait", "paysage"]).optional().describe("Orientation. Default: portrait"),
        background: z.string().optional().describe("Background color hex. Default: #ffffff"),
        category: z.string().optional().describe("Document category for grouping. Default: general"),
      }),
    },
    handler: async (args: Record<string, unknown>, _extra: ToolExtra) => {
      const name = args.name as string;
      const fmt = (args.format as string) ?? "A4";
      const orient = (args.orientation as string) ?? "portrait";
      const bg = (args.background as string) ?? "#ffffff";
      const category = (args.category as string) ?? "general";

      const dims = FORMATS[fmt];
      if (!dims) return text(`Unknown format: ${fmt}`);

      const isLandscape = orient === "paysage" && !SCREEN_FORMATS.has(fmt);
      const w = isLandscape ? dims.h : dims.w;
      const h = isLandscape ? dims.w : dims.h;

      return withClient(async (client) => {
        const { rows } = await client.query(
          `SELECT document.canvas_create($1, $2, $3, $4, $5, $6, $7) as id`,
          [name, fmt, orient, w, h, bg, category],
        );
        const id = rows[0]?.id;
        return text(`Canvas "${name}" created\nformat: ${fmt} ${orient} (${w}x${h}mm)\nbackground: ${bg}\ncategory: ${category}\nid: ${id}`);
      });
    },
  };
}
