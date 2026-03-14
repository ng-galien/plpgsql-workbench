/**
 * Meta + Assets tools — update_meta, list_assets, show_message
 */

import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createUpdateMetaTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_update_meta",
      description: "Update document metadata: design notes, team notes, and rating (0-5 stars).",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        designNotes: z.string().optional().describe("Design insights and rationale"),
        teamNotes: z.string().optional().describe("Team feedback or review notes"),
        rating: z.number().optional().describe("Quality rating 0-5"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const meta: Record<string, unknown> = {};
        if (args.designNotes !== undefined) meta.designNotes = args.designNotes;
        if (args.teamNotes !== undefined) meta.teamNotes = args.teamNotes;
        if (args.rating !== undefined) meta.rating = Math.min(5, Math.max(0, args.rating as number));

        await client.query(`UPDATE document.canvas SET meta = meta || $2, updated_at = now() WHERE id = $1`, [
          args.canvas_id,
          JSON.stringify(meta),
        ]);
        return text(`Meta updated${args.rating !== undefined ? ` (rating: ${meta.rating}/5)` : ""}`);
      });
    },
  };
}

export function createListAssetsTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_list_assets",
      description: "List available image assets. Filter by status, tags, or search.",
      schema: z.object({
        status: z.string().optional().describe("Filter: to_classify, classified, archived"),
        tags: z.array(z.string()).optional().describe("Filter by tags (any match)"),
        q: z.string().optional().describe("Full-text search on title/description"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows } = await client.query(
          `SELECT a.id, a.filename, a.title, a.status, a.tags, a.width, a.height, a.usage_hint
           FROM asset.asset a
           WHERE ($1::text IS NULL OR a.status = $1)
             AND ($2::text[] IS NULL OR a.tags && $2)
             AND ($3::text IS NULL OR a.search_vec @@ plainto_tsquery('pgv_search', $3))
           ORDER BY a.created_at DESC
           LIMIT 50`,
          [args.status ?? null, args.tags ?? null, args.q ?? null],
        );
        if (rows.length === 0) return text("No assets found.");
        const lines = rows.map((r: any) => {
          const tags = r.tags?.length > 0 ? ` [${r.tags.slice(0, 4).join(", ")}]` : "";
          const dims = r.width ? ` ${r.width}×${r.height}` : "";
          return `- ${r.id.slice(0, 8)} ${r.filename} "${r.title ?? "?"}"${tags}${dims} (${r.status})`;
        });
        return text(`${rows.length} asset(s):\n${lines.join("\n")}`);
      });
    },
  };
}

export function createShowMessageTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_show_message",
      description: "Display a toast notification in the Illustrator UI. Writes to PG session — browser polls.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        text: z.string().describe("Message to display"),
        level: z.enum(["info", "success", "warning"]).optional().describe("Toast level. Default: info"),
        duration: z.number().optional().describe("Display duration in ms. Default: 3000"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        // Update toast on ALL sessions for this canvas (all connected users see it)
        await client.query(`UPDATE document.session SET toast = $2, updated_at = now() WHERE canvas_id = $1`, [
          args.canvas_id,
          JSON.stringify({
            text: args.text,
            level: args.level ?? "info",
            duration: args.duration ?? 3000,
            at: new Date().toISOString(),
          }),
        ]);
        return text(`Toast sent: "${args.text}" (${args.level ?? "info"})`);
      });
    },
  };
}

export function createExportSvgTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_export_svg",
      description: "Export canvas as standalone SVG markup.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows } = await client.query(`SELECT document.canvas_render_svg_mini($1) as svg`, [args.canvas_id]);
        if (!rows[0]?.svg) return text("Canvas not found or empty.");
        return text(rows[0].svg);
      });
    },
  };
}

export function createCheckLayoutTool({ withClient: _withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_check_layout",
      description:
        "Analyze layout for collisions, out-of-bounds, bleed zone, spacing issues. Returns diagnostic report.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
      }),
    },
    handler: async (_args, _extra) => {
      // TODO: Port layout.ts analysis (requires loadCanvas + bbox computation)
      return text("check_layout: not yet implemented (requires positioning engine port)");
    },
  };
}

export function createMeasureTextTool(): ToolHandler {
  return {
    metadata: {
      name: "ill_measure_text",
      description: "Measure text dimensions before placing. Returns line count, width, height in mm.",
      schema: z.object({
        text: z.string().describe("Text to measure"),
        fontSize: z.number().describe("Font size in mm"),
        fontFamily: z.string().optional().describe("Font family"),
        fontWeight: z.string().optional().describe("Font weight"),
        maxWidth: z.number().optional().describe("Max width for word-wrap in mm"),
      }),
    },
    handler: async (args, _extra) => {
      // TODO: Port fonts.ts with opentype.js
      // For now, approximate: charWidth ≈ fontSize * 0.55
      const charW = (args.fontSize as number) * 0.55;
      const textStr = args.text as string;
      const maxW = args.maxWidth as number | undefined;
      const lineH = (args.fontSize as number) * 1.3;

      let lines: string[];
      if (maxW) {
        const charsPerLine = Math.floor(maxW / charW);
        const words = textStr.split(/\s+/);
        lines = [];
        let current = "";
        for (const w of words) {
          if (current.length + w.length + 1 > charsPerLine && current.length > 0) {
            lines.push(current);
            current = w;
          } else {
            current = current ? `${current} ${w}` : w;
          }
        }
        if (current) lines.push(current);
      } else {
        lines = textStr.split("\n");
      }

      const width = Math.max(...lines.map((l) => l.length * charW));
      const height = lines.length * lineH;

      return text(
        `lines: ${lines.length}\nwidth: ${width.toFixed(1)}mm\nheight: ${height.toFixed(1)}mm\nlineHeight: ${lineH.toFixed(1)}mm`,
      );
    },
  };
}
