/**
 * get_state — Get current canvas state + session (selection, phase) in compact or full format.
 */

import { z } from "zod";
import type { ToolExtra, ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { compactState, loadCanvas } from "./state.js";

export function createGetStateTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_get_state",
      description:
        "Get canvas state + user session (selection, phase). Default: compact text. Use format='full' for JSON.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        format: z.enum(["compact", "full"]).optional().describe("Output format. Default: compact"),
      }),
    },
    handler: async (args: Record<string, unknown>, _extra: ToolExtra) => {
      const canvasId = args.canvas_id as string;
      const format = (args.format as string) ?? "compact";

      return withClient(async (client) => {
        const loaded = await loadCanvas(client, canvasId);
        if (!loaded) return text(`Canvas not found: ${canvasId}`);

        // Read session (UNLOGGED table — selection, phase, zoom)
        const { rows: sessionRows } = await client.query(
          `SELECT selected_ids, phase, zoom, toast FROM document.session WHERE canvas_id = $1 LIMIT 1`,
          [canvasId],
        );
        const session = sessionRows[0] ?? { selected_ids: [], phase: "idle", zoom: 1, toast: null };

        if (format === "full") {
          return text(JSON.stringify({ ...loaded, session }, null, 2));
        }

        // Compact: add session info header
        const selectedStr =
          Array.isArray(session.selected_ids) && session.selected_ids.length > 0
            ? `selected: [${session.selected_ids.map((id: string) => id.slice(0, 8)).join(", ")}]`
            : "selected: none";
        const sessionLine = `${selectedStr}  phase: ${session.phase}  zoom: ${session.zoom}`;

        return text(`${compactState(loaded)}\n${sessionLine}`);
      });
    },
  };
}
