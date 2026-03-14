/**
 * Document CRUD tools — doc_list, doc_load, doc_delete, doc_duplicate, doc_rename, doc_save, canvas_setup
 */

import { z } from "zod";
import type { ToolHandler, ToolExtra, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { FORMATS, SCREEN_FORMATS } from "./types.js";

export function createDocListTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_doc_list",
      description: "List all canvas documents.",
      schema: z.object({
        category: z.string().optional().describe("Filter by category"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows } = await client.query(
          `SELECT c.id, c.name, c.category, c.format, c.orientation, c.width, c.height,
                  (SELECT count(*) FROM document.element e WHERE e.canvas_id = c.id) as elements,
                  c.updated_at
           FROM document.canvas c
           WHERE ($1::text IS NULL OR c.category = $1)
           ORDER BY c.updated_at DESC`,
          [args.category ?? null],
        );
        if (rows.length === 0) return text("No documents found.");
        const lines = rows.map((r: any) =>
          `- "${r.name}" [${r.category}] ${r.format} ${r.orientation} (${r.elements} elements)  id: ${r.id}`
        );
        return text(`${rows.length} document(s):\n${lines.join("\n")}`);
      });
    },
  };
}

export function createDocLoadTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_doc_load",
      description: "Load a canvas document by name or ID. Returns compact state.",
      schema: z.object({
        name: z.string().describe("Document name or UUID"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows } = await client.query(
          `SELECT id, name, format, orientation, width, height,
                  (SELECT count(*) FROM document.element e WHERE e.canvas_id = c.id) as elements
           FROM document.canvas c
           WHERE c.id::text = $1 OR c.name = $1 LIMIT 1`,
          [args.name as string],
        );
        if (rows.length === 0) return text(`Document not found: ${args.name}`);
        const r = rows[0];
        return text(`Loaded "${r.name}" (${r.format} ${r.orientation}, ${r.elements} elements)\nid: ${r.id}`);
      });
    },
  };
}

export function createDocDeleteTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_doc_delete",
      description: "Delete a canvas document permanently. Refuses if it's the only one.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID to delete"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows: countRows } = await client.query(`SELECT count(*) as cnt FROM document.canvas`);
        if (parseInt(countRows[0].cnt) <= 1) return text("Cannot delete the only document.");
        const { rows } = await client.query(
          `DELETE FROM document.canvas WHERE id = $1 RETURNING name`,
          [args.canvas_id],
        );
        if (rows.length === 0) return text(`Canvas not found: ${args.canvas_id}`);
        return text(`Deleted "${rows[0].name}"`);
      });
    },
  };
}

export function createDocDuplicateTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_doc_duplicate",
      description: "Clone a canvas document with a new name. Copies all elements.",
      schema: z.object({
        canvas_id: z.string().describe("Source canvas UUID"),
        name: z.string().describe("Name for the new clone"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows } = await client.query(
          `SELECT document.canvas_duplicate($1, $2) as id`,
          [args.canvas_id, args.name],
        );
        const id = rows[0]?.id;
        return text(`Duplicated -> "${args.name}"\nid: ${id}`);
      });
    },
  };
}

export function createDocRenameTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_doc_rename",
      description: "Rename a canvas document.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        name: z.string().describe("New name"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        await client.query(
          `UPDATE document.canvas SET name = $2, updated_at = now() WHERE id = $1`,
          [args.canvas_id, args.name],
        );
        return text(`Renamed -> "${args.name}"`);
      });
    },
  };
}

export function createDocSaveTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_doc_save",
      description: "Touch updated_at on a canvas (persistence is automatic in PG).",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        await client.query(
          `UPDATE document.canvas SET updated_at = now() WHERE id = $1`,
          [args.canvas_id],
        );
        return text(`Saved.`);
      });
    },
  };
}

export function createCanvasSetupTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_canvas_setup",
      description: "Change canvas format, orientation, or background color.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        format: z.enum(["A2", "A3", "A4", "A5", "HD", "MACBOOK", "IPAD", "MOBILE"]).optional(),
        orientation: z.enum(["portrait", "paysage"]).optional(),
        background: z.string().optional().describe("Background color hex"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows: current } = await client.query(
          `SELECT format, orientation, background FROM document.canvas WHERE id = $1`,
          [args.canvas_id],
        );
        if (current.length === 0) return text(`Canvas not found: ${args.canvas_id}`);

        const fmt = (args.format as string) ?? current[0].format;
        const orient = (args.orientation as string) ?? current[0].orientation;
        const bg = (args.background as string) ?? current[0].background;
        const dims = FORMATS[fmt];
        if (!dims) return text(`Unknown format: ${fmt}`);
        const isLandscape = orient === "paysage" && !SCREEN_FORMATS.has(fmt);
        const w = isLandscape ? dims.h : dims.w;
        const h = isLandscape ? dims.w : dims.h;

        await client.query(
          `UPDATE document.canvas SET format=$2, orientation=$3, width=$4, height=$5, background=$6, updated_at=now() WHERE id=$1`,
          [args.canvas_id, fmt, orient, w, h, bg],
        );
        return text(`Canvas: ${fmt} ${orient} (${w}×${h}mm) bg=${bg}`);
      });
    },
  };
}
