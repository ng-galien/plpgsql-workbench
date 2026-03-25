/**
 * broadcast.ts — AI activity broadcast service
 *
 * Sends real-time notifications from MCP tools to the browser
 * via Supabase Realtime Broadcast channel.
 *
 * Two modes:
 * - Live: Broadcast on 'ai-activity' channel (ephemeral, instant)
 * - Persist: Also INSERT into workbench.agent_message (history)
 */

import { createClient, type RealtimeChannel, type SupabaseClient } from "@supabase/supabase-js";
import type { WithClient } from "./container.js";

export interface BroadcastPayload {
  // Display
  type?: "toast" | "card" | "progress" | "dialog";
  msg: string;
  detail?: string;
  level?: "info" | "success" | "warning" | "error";

  // Navigation
  href?: string;
  action?: "navigate";

  // pgView primitives
  badge?: string;
  badgeVariant?: "success" | "danger" | "warning" | "info" | "primary";
  icon?: string;
  progress?: number;

  // Actions
  actions?: {
    label: string;
    href?: string;
    rpc?: string;
    params?: Record<string, unknown>;
    variant?: "primary" | "secondary" | "danger";
  }[];

  // Persistence
  persist?: boolean;
}

export type BroadcastFn = (payload: BroadcastPayload) => Promise<void>;

export function createBroadcastService({ withClient }: { withClient: WithClient }): BroadcastFn {
  let client: SupabaseClient | null = null;
  let channel: RealtimeChannel | null = null;

  async function ensureChannel(): Promise<RealtimeChannel> {
    if (channel) return channel;

    // Read Supabase URL + anon key from workbench.config
    const config = await withClient(async (db) => {
      const { rows } = await db.query<{ key: string; value: string }>(
        `SELECT key, value FROM workbench.config WHERE app = 'supabase'`,
      );
      return Object.fromEntries(rows.map((r) => [r.key, r.value]));
    });

    const url = config.url || process.env.SUPABASE_URL || "http://localhost:54321";
    const key = config.anon_key || process.env.SUPABASE_ANON_KEY || "";

    if (!client) {
      client = createClient(url, key);
    }

    channel = client.channel("ai-activity");
    await new Promise<void>((resolve, reject) => {
      channel!.subscribe((status) => {
        if (status === "SUBSCRIBED") resolve();
        else if (status === "CHANNEL_ERROR") reject(new Error("Broadcast channel error"));
      });
    });

    return channel;
  }

  return async function broadcast(payload: BroadcastPayload): Promise<void> {
    // 1. Live broadcast
    try {
      const ch = await ensureChannel();
      await ch.send({ type: "broadcast", event: "activity", payload });
    } catch (err) {
      // Non-fatal — broadcast is best-effort
      console.warn("[broadcast] failed:", err);
    }

    // 2. Persist if requested
    if (payload.persist) {
      try {
        await withClient(async (db) => {
          await db.query(
            `INSERT INTO workbench.agent_message (from_module, to_module, msg_type, subject, body, payload)
             VALUES ('ai', 'user', 'notification', $1, $2, $3)`,
            [payload.msg, payload.detail || null, JSON.stringify(payload)],
          );
        });
      } catch (err) {
        console.warn("[broadcast] persist failed:", err);
      }
    }
  };
}
