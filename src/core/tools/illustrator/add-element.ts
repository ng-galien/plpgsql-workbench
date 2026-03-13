/**
 * add_text, add_rect, add_line — Element creation tools.
 * Each builds a props JSONB and calls document.element_add().
 */

import { z } from "zod";
import type { ToolHandler, ToolExtra, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createAddTextTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_add_text",
      description: "Add text to a canvas. fontSize in mm (~12-15 for titles, ~6-8 for subtitles, ~4-5 for body). Use maxWidth for auto word-wrap.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        text: z.string().describe("Text content"),
        x: z.number().describe("X position in mm"),
        y: z.number().describe("Y position in mm (baseline)"),
        name: z.string().optional().describe("Semantic name for referencing"),
        fontSize: z.number().optional().describe("Font size in mm. Default: 8"),
        fontFamily: z.string().optional().describe("Font family. Default: Libre Baskerville"),
        fontWeight: z.string().optional().describe("Font weight: normal, bold, 300, 600, 700. Default: bold"),
        fontStyle: z.string().optional().describe("Font style: normal, italic. Default: normal"),
        fill: z.string().optional().describe("Text color hex. Default: #1C1C1C"),
        textAnchor: z.string().optional().describe("Alignment: start, middle, end. Default: start"),
        maxWidth: z.number().optional().describe("Max width for word-wrap in mm"),
        opacity: z.number().optional().describe("Opacity 0-1. Default: 1"),
        rotation: z.number().optional().describe("Rotation in degrees. Default: 0"),
      }),
    },
    handler: async (args: Record<string, unknown>, _extra: ToolExtra) => {
      const canvasId = args.canvas_id as string;
      const props: Record<string, unknown> = {
        x: args.x,
        y: args.y,
        content: args.text,
        fontSize: args.fontSize ?? 8,
        fontFamily: args.fontFamily ?? "Libre Baskerville",
        fontWeight: args.fontWeight ?? "bold",
        fontStyle: args.fontStyle ?? "normal",
        textAnchor: args.textAnchor ?? "start",
        maxWidth: args.maxWidth ?? null,
      };

      return withClient(async (client) => {
        const { rows } = await client.query(
          `SELECT document.element_add($1, 'text', 0, $2) as id`,
          [canvasId, JSON.stringify({
            ...props,
            name: args.name ?? null,
            fill: args.fill ?? "#1C1C1C",
            opacity: args.opacity ?? 1,
            rotation: args.rotation ?? 0,
          })],
        );
        const id = rows[0]?.id;
        const preview = (args.text as string).slice(0, 30);
        return text(`Text "${preview}" -> ${String(id).slice(0, 8)} at x:${args.x} y:${args.y}`);
      });
    },
  };
}

export function createAddRectTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_add_rect",
      description: "Add a rectangle to a canvas.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        x: z.number().describe("X position in mm"),
        y: z.number().describe("Y position in mm"),
        width: z.number().describe("Width in mm"),
        height: z.number().describe("Height in mm"),
        name: z.string().optional().describe("Semantic name"),
        fill: z.string().optional().describe("Fill color. Default: #000000"),
        stroke: z.string().optional().describe("Stroke color. Default: none"),
        strokeWidth: z.number().optional().describe("Stroke width in mm. Default: 0"),
        rx: z.number().optional().describe("Border radius in mm. Default: 0"),
        opacity: z.number().optional().describe("Opacity 0-1. Default: 1"),
        rotation: z.number().optional().describe("Rotation degrees. Default: 0"),
      }),
    },
    handler: async (args: Record<string, unknown>, _extra: ToolExtra) => {
      const canvasId = args.canvas_id as string;

      return withClient(async (client) => {
        const { rows } = await client.query(
          `SELECT document.element_add($1, 'rect', 0, $2) as id`,
          [canvasId, JSON.stringify({
            x: args.x, y: args.y, width: args.width, height: args.height,
            name: args.name ?? null,
            fill: args.fill ?? "#000000",
            stroke: args.stroke ?? "none",
            stroke_width: args.strokeWidth ?? 0,
            rx: args.rx ?? 0,
            opacity: args.opacity ?? 1,
            rotation: args.rotation ?? 0,
          })],
        );
        const id = rows[0]?.id;
        return text(`Rect -> ${String(id).slice(0, 8)} at x:${args.x} y:${args.y} ${args.width}x${args.height}mm`);
      });
    },
  };
}

export function createAddLineTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_add_line",
      description: "Add a line to a canvas.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        x1: z.number().describe("Start X in mm"),
        y1: z.number().describe("Start Y in mm"),
        x2: z.number().describe("End X in mm"),
        y2: z.number().describe("End Y in mm"),
        name: z.string().optional().describe("Semantic name"),
        stroke: z.string().optional().describe("Stroke color. Default: #000000"),
        strokeWidth: z.number().optional().describe("Stroke width in mm. Default: 0.5"),
        opacity: z.number().optional().describe("Opacity 0-1. Default: 1"),
        rotation: z.number().optional().describe("Rotation degrees. Default: 0"),
      }),
    },
    handler: async (args: Record<string, unknown>, _extra: ToolExtra) => {
      const canvasId = args.canvas_id as string;

      return withClient(async (client) => {
        const { rows } = await client.query(
          `SELECT document.element_add($1, 'line', 0, $2) as id`,
          [canvasId, JSON.stringify({
            x1: args.x1, y1: args.y1, x2: args.x2, y2: args.y2,
            name: args.name ?? null,
            stroke: args.stroke ?? "#000000",
            stroke_width: args.strokeWidth ?? 0.5,
            opacity: args.opacity ?? 1,
            rotation: args.rotation ?? 0,
          })],
        );
        const id = rows[0]?.id;
        return text(`Line -> ${String(id).slice(0, 8)} (${args.x1},${args.y1}) -> (${args.x2},${args.y2})`);
      });
    },
  };
}
