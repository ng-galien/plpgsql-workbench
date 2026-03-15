/**
 * realtime.ts — Supabase client singleton + Realtime event bus
 *
 * Single Supabase client shared by the entire shell.
 * Components subscribe via pgListen(), the bus handles channel lifecycle.
 */

import { createClient, type RealtimeChannel, type SupabaseClient } from "@supabase/supabase-js";
import { getConfig } from "./config.js";
import type { PgChangeHandler, PgChangePayload } from "./types.js";

let client: SupabaseClient | null = null;
const channels: Record<string, RealtimeChannel> = {};
const listeners: Record<string, PgChangeHandler[]> = {};

/** Lazy-init Supabase client singleton */
export function supabase(): SupabaseClient {
  if (!client) {
    const cfg = getConfig();
    client = createClient(cfg.supabaseUrl, cfg.supabaseKey);
  }
  return client;
}

/**
 * Subscribe to Postgres changes on a table.
 * Returns an unsubscribe function.
 *
 * Usage: pgListen('document', 'element', (payload) => { ... })
 */
export function pgListen(schema: string, table: string, handler: PgChangeHandler): () => void {
  const key = `${schema}.${table}`;

  if (!listeners[key]) listeners[key] = [];
  listeners[key].push(handler);

  // Open channel on first listener for this table (or whole schema if table is "*")
  if (!channels[key]) {
    const filter = table !== "*" ? { event: "*" as const, schema, table } : { event: "*" as const, schema };
    const ch = supabase()
      .channel(`rt-${key}`)
      .on("postgres_changes", filter, (payload: PgChangePayload) => {
        const fns = listeners[key];
        if (fns) for (const fn of fns) fn(payload);
      })
      .subscribe((status) => {
        console.log(`[pgv] Realtime channel rt-${key}: ${status}`);
      });
    channels[key] = ch;
  }

  // Return unsubscribe function
  return () => {
    const arr = listeners[key];
    if (arr) {
      const idx = arr.indexOf(handler);
      if (idx !== -1) arr.splice(idx, 1);

      // Close channel when no more listeners
      if (arr.length === 0) {
        channels[key]?.unsubscribe();
        delete channels[key];
        delete listeners[key];
      }
    }
  };
}

/**
 * Call a PostgREST RPC via the shared Supabase client.
 * Resolves with data on success, rejects with error on failure.
 */
export async function pgRpc(fn: string, params?: Record<string, unknown>, schema?: string): Promise<unknown> {
  const { data, error } = await supabase()
    .schema(schema || "public")
    .rpc(fn, params || {});
  if (error) throw error;
  return data;
}

/** Tear down all channels (eg. on shell destroy) */
export function destroyAll(): void {
  for (const ch of Object.values(channels)) ch?.unsubscribe();
  for (const k of Object.keys(channels)) delete channels[k];
  for (const k of Object.keys(listeners)) delete listeners[k];
  client = null;
}
