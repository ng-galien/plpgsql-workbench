/**
 * ill_doc — Document lifecycle. Replaces doc_new/list/load/delete/duplicate/rename/save/canvas_setup.
 */

import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { FORMATS, SCREEN_FORMATS } from "./types.js";

export function createIllDocTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_doc",
      description: `Document lifecycle operations.

Actions:
- new: Create canvas. Args: name, format (A2-A5/HD/MACBOOK/IPAD/MOBILE), orientation (portrait/paysage), background (#hex), category
- list: List all canvases. Args: category (optional filter)
- load: Load by name or ID. Args: id (name or UUID)
- delete: Delete canvas. Args: id (UUID)
- duplicate: Clone canvas + elements. Args: id (source UUID), name (new name)
- rename: Rename canvas. Args: id (UUID), name (new name)
- setup: Change format/orientation/background. Args: id (UUID), format, orientation, background
- clear: Remove all elements. Args: id (UUID)`,
      schema: z.object({
        action: z
          .enum(["new", "list", "load", "delete", "duplicate", "rename", "setup", "clear"])
          .describe("Operation"),
        name: z.string().optional().describe("Document name (new, duplicate, rename)"),
        id: z.string().optional().describe("Canvas UUID or name (load, delete, duplicate, rename, setup, clear)"),
        format: z.string().optional().describe("Canvas format (new, setup)"),
        orientation: z.string().optional().describe("Orientation (new, setup)"),
        background: z.string().optional().describe("Background color (new, setup)"),
        category: z.string().optional().describe("Category (new, list)"),
      }),
    },
    handler: async (args, _extra) => {
      const action = args.action as string;

      return withClient(async (client) => {
        switch (action) {
          case "new": {
            const name = args.name as string;
            if (!name) return text("name is required");
            const fmt = (args.format as string) ?? "A4";
            const orient = (args.orientation as string) ?? "portrait";
            const bg = (args.background as string) ?? "#ffffff";
            const cat = (args.category as string) ?? "general";
            const dims = FORMATS[fmt];
            if (!dims) return text(`Unknown format: ${fmt}`);
            const isLandscape = orient === "paysage" && !SCREEN_FORMATS.has(fmt);
            const w = isLandscape ? dims.h : dims.w;
            const h = isLandscape ? dims.w : dims.h;
            const { rows } = await client.query(`SELECT document.canvas_create($1, $2, $3, $4, $5, $6, $7) as id`, [
              name,
              fmt,
              orient,
              w,
              h,
              bg,
              cat,
            ]);
            return text(`Canvas "${name}" [${cat}] ${fmt} ${orient} (${w}×${h}mm) bg:${bg}\nid: ${rows[0]?.id}`);
          }

          case "list": {
            const { rows } = await client.query(
              `SELECT id, name, category, format, orientation, width, height,
                      (SELECT count(*) FROM document.element e WHERE e.canvas_id = c.id) as elements
               FROM document.canvas c
               WHERE ($1::text IS NULL OR c.category = $1)
               ORDER BY c.updated_at DESC`,
              [args.category ?? null],
            );
            if (rows.length === 0) return text("No documents.");
            const lines = rows.map(
              (r: any) => `- "${r.name}" [${r.category}] ${r.format} ${r.orientation} (${r.elements} el)  id: ${r.id}`,
            );
            return text(`${rows.length} document(s):\n${lines.join("\n")}`);
          }

          case "load": {
            if (!args.id) return text("id is required");
            const { rows } = await client.query(
              `SELECT id, name, format, orientation, width, height,
                      (SELECT count(*) FROM document.element e WHERE e.canvas_id = c.id) as elements
               FROM document.canvas c WHERE c.id::text = $1 OR c.name = $1 LIMIT 1`,
              [args.id as string],
            );
            if (rows.length === 0) return text(`Not found: ${args.id}`);
            const r = rows[0];
            return text(`"${r.name}" ${r.format} ${r.orientation} (${r.elements} elements)\nid: ${r.id}`);
          }

          case "delete": {
            if (!args.id) return text("id is required");
            const { rows: countRows } = await client.query(`SELECT count(*) as cnt FROM document.canvas`);
            if (parseInt(countRows[0].cnt, 10) <= 1) return text("Cannot delete the only document.");
            const { rows } = await client.query(`DELETE FROM document.canvas WHERE id = $1 RETURNING name`, [args.id]);
            if (rows.length === 0) return text(`Not found: ${args.id}`);
            return text(`Deleted "${rows[0].name}"`);
          }

          case "duplicate": {
            if (!args.id || !args.name) return text("id and name are required");
            const { rows } = await client.query(`SELECT document.canvas_duplicate($1, $2) as id`, [args.id, args.name]);
            return text(`Duplicated -> "${args.name}"\nid: ${rows[0]?.id}`);
          }

          case "rename": {
            if (!args.id || !args.name) return text("id and name are required");
            await client.query(`UPDATE document.canvas SET name = $2, updated_at = now() WHERE id = $1`, [
              args.id,
              args.name,
            ]);
            return text(`Renamed -> "${args.name}"`);
          }

          case "setup": {
            if (!args.id) return text("id is required");
            const { rows: cur } = await client.query(
              `SELECT format, orientation, background FROM document.canvas WHERE id = $1`,
              [args.id],
            );
            if (cur.length === 0) return text(`Not found: ${args.id}`);
            const fmt = (args.format as string) ?? cur[0].format;
            const orient = (args.orientation as string) ?? cur[0].orientation;
            const bg = (args.background as string) ?? cur[0].background;
            const dims = FORMATS[fmt];
            if (!dims) return text(`Unknown format: ${fmt}`);
            const isLandscape = orient === "paysage" && !SCREEN_FORMATS.has(fmt);
            const w = isLandscape ? dims.h : dims.w;
            const h = isLandscape ? dims.w : dims.h;
            await client.query(
              `UPDATE document.canvas SET format=$2, orientation=$3, width=$4, height=$5, background=$6, updated_at=now() WHERE id=$1`,
              [args.id, fmt, orient, w, h, bg],
            );
            return text(`Canvas: ${fmt} ${orient} (${w}×${h}mm) bg=${bg}`);
          }

          case "clear": {
            if (!args.id) return text("id is required");
            const { rows } = await client.query(`SELECT document.canvas_clear($1) as count`, [args.id]);
            return text(`Cleared (${rows[0]?.count ?? 0} elements removed)`);
          }

          default:
            return text(`Unknown action: ${action}`);
        }
      });
    },
  };
}
