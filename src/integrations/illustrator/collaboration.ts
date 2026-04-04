/**
 * Collaboration tools — inspect_store, dispatch_event, get_event_log
 *
 * Reads/writes the PG UNLOGGED session table instead of Supabase Realtime Broadcast.
 * The browser syncs its ephemeral state (selection, phase) to PG session.
 * Claude reads it here when needed.
 */

import { z } from "zod";
import type { ToolHandler, WithClient } from "../../core/container.js";
import { text } from "../../core/helpers.js";

export function createInspectStoreTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_inspect_store",
      description:
        "Read the user's browser state: selection, phase, zoom. Reads from PG session table (synced by the browser).",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const { rows } = await client.query(
          `SELECT user_id, selected_ids, phase, zoom, toast, updated_at
           FROM document.session WHERE canvas_id = $1`,
          [args.canvas_id],
        );
        if (rows.length === 0) {
          return text("No active session for this canvas.\nhint: open the document in a browser to create a session.");
        }
        const lines = rows.map((r: any) => {
          const selected =
            Array.isArray(r.selected_ids) && r.selected_ids.length > 0
              ? r.selected_ids.map((id: string) => String(id).slice(0, 8)).join(", ")
              : "none";
          const ago = r.updated_at
            ? `(${Math.round((Date.now() - new Date(r.updated_at).getTime()) / 1000)}s ago)`
            : "";
          return `user: ${r.user_id}\n  selected: [${selected}]\n  phase: ${r.phase}\n  zoom: ${r.zoom}\n  toast: ${r.toast ? JSON.stringify(r.toast) : "none"}\n  updated: ${ago}`;
        });
        return text(lines.join("\n---\n"));
      });
    },
  };
}

export function createDispatchEventTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_dispatch_event",
      description:
        "Write to the session to simulate user actions (select element, change phase). The browser polls the session and reacts.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        selected_ids: z
          .array(z.string())
          .optional()
          .describe("Set selection to these element IDs. Pass empty array to deselect."),
        phase: z.enum(["idle", "selected", "editing_prop"]).optional().describe("Set UI phase"),
      }),
    },
    handler: async (args, _extra) => {
      return withClient(async (client) => {
        const sets: string[] = [];
        const params: unknown[] = [args.canvas_id];
        let idx = 2;

        if (args.selected_ids !== undefined) {
          sets.push(`selected_ids = $${idx}`);
          params.push(JSON.stringify(args.selected_ids));
          idx++;
        }
        if (args.phase !== undefined) {
          sets.push(`phase = $${idx}`);
          params.push(args.phase);
          idx++;
        }
        sets.push("updated_at = now()");

        if (sets.length <= 1) return text("Nothing to dispatch. Provide selected_ids or phase.");

        await client.query(`UPDATE document.session SET ${sets.join(", ")} WHERE canvas_id = $1`, params);
        return text(
          `Dispatched: ${args.selected_ids !== undefined ? `selected=[${(args.selected_ids as string[]).join(",")}]` : ""} ${args.phase ?? ""}`,
        );
      });
    },
  };
}

export function createGetEventLogTool(_deps: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "ill_get_event_log",
      description:
        "Not available in PG-session mode. The event log is client-side only (Zustand store). Use ill_inspect_store to read current state.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
      }),
    },
    handler: async (_args, _extra) => {
      return text("Event log is client-side only (Zustand). Use ill_inspect_store to read current session state.");
    },
  };
}
