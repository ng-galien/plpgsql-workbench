/**
 * get_state — Get current canvas state in compact or full format.
 */

import { z } from "zod";
import type { ToolHandler, ToolExtra, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { loadCanvas, compactState } from "./state.js";

export function createGetStateTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_get_state",
      description: "Get canvas document state. Default: compact text (token-efficient). Use format='full' for complete JSON.",
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

        if (format === "full") {
          return text(JSON.stringify(loaded, null, 2));
        }
        return text(compactState(loaded));
      });
    },
  };
}
