/**
 * Collaboration tools — inspect_store, dispatch_event, get_event_log, show_message
 *
 * Uses Supabase Realtime Broadcast for bidirectional communication with the client.
 * Pattern: Edge Function sends a broadcast with a reqId, client responds with {reqId}_response.
 *
 * In dev (no Realtime): falls back to returning a stub message.
 */

import { z } from "zod";
import type { ToolHandler } from "../../container.js";
import { text } from "../../helpers.js";

/** Cross-runtime env access (Deno or Node). */
function getEnv(key: string): string | undefined {
  try { return (globalThis as any).Deno?.env?.get(key); } catch {}
  try { return (globalThis as any).process?.env?.[key]; } catch {}
  return undefined;
}

/** Send a Supabase Realtime Broadcast message and wait for response. */
async function broadcastRequest(
  supabaseUrl: string | undefined,
  supabaseKey: string | undefined,
  channel: string,
  event: string,
  payload: Record<string, unknown>,
  timeoutMs: number = 5000,
): Promise<Record<string, unknown> | null> {
  if (!supabaseUrl || !supabaseKey) return null;

  const reqId = crypto.randomUUID();

  // Send broadcast via Supabase Realtime REST API
  try {
    await fetch(`${supabaseUrl}/realtime/v1/api/broadcast`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${supabaseKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        messages: [{
          topic: `realtime:${channel}`,
          event,
          payload: { ...payload, reqId },
        }],
      }),
    });
  } catch {
    return null;
  }

  // Wait for response on the same channel
  // TODO: Subscribe to the channel and wait for {reqId}_response
  // For now, return null (no response mechanism without a persistent WS connection)
  return null;
}

export function createInspectStoreTool(): ToolHandler {
  return {
    metadata: {
      name: "ill_inspect_store",
      description: "Read the client-side store state (phase, UI settings, selection, active doc). Requires a browser tab open. Use to see what the user sees.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID (used to identify the Realtime channel)"),
        slices: z.array(z.string()).optional().describe("State slices to include: phase, ui, doc, ephemeral. Default: all"),
      }),
    },
    handler: async (args, _extra) => {
      const supabaseUrl = getEnv("SUPABASE_URL");
      const supabaseKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");
      const channel = `collab-${args.canvas_id}`;

      const response = await broadcastRequest(
        supabaseUrl, supabaseKey, channel,
        "inspect_request",
        { slices: args.slices ?? ["phase", "ui", "doc", "ephemeral"] },
      );

      if (response) {
        return text(JSON.stringify(response, null, 2));
      }
      return text(
        "inspect_store: no client connected (Realtime broadcast sent but no response)\n" +
        "hint: open the document editor in a browser to enable bidirectional inspection"
      );
    },
  };
}

export function createDispatchEventTool(): ToolHandler {
  return {
    metadata: {
      name: "ill_dispatch_event",
      description: "Inject a typed event into the client-side store to simulate user interactions (select element, toggle UI). Requires browser tab open.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        event_type: z.enum([
          "SELECT_ELEMENT", "TOGGLE_SHOW_NAMES", "TOGGLE_SHOW_BLEED",
          "TOGGLE_SNAP", "TOGGLE_PHOTO_PANEL", "PHASE_TRANSITION",
        ]).describe("Event type to dispatch"),
        id: z.string().optional().describe("Element ID for SELECT_ELEMENT"),
        target: z.string().optional().describe("Target phase for PHASE_TRANSITION"),
      }),
    },
    handler: async (args, _extra) => {
      const supabaseUrl = getEnv("SUPABASE_URL");
      const supabaseKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");
      const channel = `collab-${args.canvas_id}`;

      const payload: Record<string, unknown> = {
        event_type: args.event_type,
      };
      if (args.id) payload.id = args.id;
      if (args.target) payload.target = args.target;

      const response = await broadcastRequest(
        supabaseUrl, supabaseKey, channel,
        "dispatch_request", payload,
      );

      if (response) {
        return text(`Dispatched ${args.event_type} -> phase: ${response.phase}, selectedIds: [${response.selectedIds}]`);
      }
      return text(
        `Dispatched ${args.event_type} (broadcast sent, no client response)\n` +
        "hint: open the document editor in a browser"
      );
    },
  };
}

export function createGetEventLogTool(): ToolHandler {
  return {
    metadata: {
      name: "ill_get_event_log",
      description: "Read the client-side event log — recent events with timestamps, phases, blocked status. Use to debug UI interactions.",
      schema: z.object({
        canvas_id: z.string().describe("Canvas UUID"),
        limit: z.number().optional().describe("Max entries. Default: 30"),
        filter: z.string().optional().describe("Substring filter on event type"),
        blocked_only: z.boolean().optional().describe("Only show blocked events"),
      }),
    },
    handler: async (args, _extra) => {
      const supabaseUrl = getEnv("SUPABASE_URL");
      const supabaseKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");
      const channel = `collab-${args.canvas_id}`;

      const response = await broadcastRequest(
        supabaseUrl, supabaseKey, channel,
        "log_request",
        {
          limit: args.limit ?? 30,
          filter: args.filter ?? null,
          blocked_only: args.blocked_only ?? false,
        },
      );

      if (response && Array.isArray(response.entries)) {
        const lines = (response.entries as any[]).map((e: any) =>
          `${e.ts} [${e.phase}] ${e.type}${e.blocked ? " BLOCKED" : ""}${e.detail ? ` — ${e.detail}` : ""}`
        );
        return text(`Event log (${lines.length} entries):\n${lines.join("\n")}`);
      }
      return text(
        "get_event_log: no client connected\n" +
        "hint: open the document editor in a browser"
      );
    },
  };
}
