/**
 * Supabase sync — replaces ws.ts
 *
 * - Realtime Postgres Changes: element INSERT/UPDATE/DELETE → Zustand
 * - PostgREST: CRUD operations (addElement, updateElement, etc.)
 * - Session sync: selection/phase → PG UNLOGGED table
 *
 * Uses @supabase/supabase-js loaded from CDN.
 */

// @ts-nocheck — browser globals

import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { store } from "./store.js";

let supabaseUrl = "";
let supabaseKey = "";
let supabase: SupabaseClient | null = null;
let channel: any = null;
let sessionSyncTimer: any = null;
let toastPollTimer: any = null;

/** Initialize Supabase client + subscribe to canvas changes */
export function init(url: string, key: string, canvasId: string) {
  supabaseUrl = url;
  supabaseKey = key;

  supabase = createClient(supabaseUrl, supabaseKey);

  // Load initial state
  loadCanvas(canvasId);

  // Subscribe to element changes
  channel = supabase
    .channel(`canvas-${canvasId}`)
    .on("postgres_changes", {
      event: "INSERT",
      schema: "document",
      table: "element",
      filter: `canvas_id=eq.${canvasId}`,
    }, (payload: any) => {
      const el = rowToElement(payload.new);
      store.getState().addElement(el);
    })
    .on("postgres_changes", {
      event: "UPDATE",
      schema: "document",
      table: "element",
      filter: `canvas_id=eq.${canvasId}`,
    }, (payload: any) => {
      const el = rowToElement(payload.new);
      // Don't update if we're dragging this element (optimistic local)
      const state = store.getState();
      if (state.phase === "dragging" && state.selectedIds.includes(el.id)) return;
      store.getState().updateElement(el.id, el);
    })
    .on("postgres_changes", {
      event: "DELETE",
      schema: "document",
      table: "element",
      filter: `canvas_id=eq.${canvasId}`,
    }, (payload: any) => {
      store.getState().removeElement(payload.old.id);
    })
    .subscribe();

  // Sync session (selection/phase) to PG every 500ms (debounced)
  let lastSynced = "";
  sessionSyncTimer = setInterval(() => {
    const { selectedIds, phase, zoom } = store.getState();
    const key = JSON.stringify({ selectedIds, phase, zoom });
    if (key === lastSynced) return;
    lastSynced = key;
    syncSession(canvasId, selectedIds, phase, zoom);
  }, 500);

  // Poll toast from PG session every 2s
  toastPollTimer = setInterval(() => pollToast(canvasId), 2000);
}

/** Cleanup */
export function destroy() {
  if (channel) { supabase?.removeChannel(channel); channel = null; }
  if (sessionSyncTimer) { clearInterval(sessionSyncTimer); sessionSyncTimer = null; }
  if (toastPollTimer) { clearInterval(toastPollTimer); toastPollTimer = null; }
}

/** Load canvas + elements from PG */
async function loadCanvas(canvasId: string) {
  const { data: canvas } = await supabase
    .from("canvas")
    .select("*")
    .eq("id", canvasId)
    .single();

  if (!canvas) {
    console.error("Canvas not found:", canvasId);
    return;
  }

  store.getState().setCanvas({
    id: canvas.id,
    name: canvas.name,
    format: canvas.format,
    orientation: canvas.orientation,
    w: canvas.width,
    h: canvas.height,
    bg: canvas.background,
    category: canvas.category,
    meta: canvas.meta ?? {},
  });

  const { data: elements } = await supabase
    .from("element")
    .select("*")
    .eq("canvas_id", canvasId)
    .order("sort_order");

  store.getState().setElements((elements ?? []).map(rowToElement));
}

/** Convert PG row to Element */
function rowToElement(row: any): any {
  return {
    id: row.id,
    type: row.type,
    name: row.name,
    parent_id: row.parent_id,
    sort_order: row.sort_order,
    x: row.x,
    y: row.y,
    width: row.width,
    height: row.height,
    x1: row.x1,
    y1: row.y1,
    x2: row.x2,
    y2: row.y2,
    cx: row.cx,
    cy: row.cy,
    r: row.r,
    opacity: row.opacity ?? 1,
    rotation: row.rotation ?? 0,
    fill: row.fill,
    stroke: row.stroke,
    stroke_width: row.stroke_width,
    props: row.props ?? {},
    asset_id: row.asset_id,
  };
}

/** Sync ephemeral state to PG UNLOGGED session */
async function syncSession(canvasId: string, selectedIds: string[], phase: string, zoom: number) {
  await supabase.rpc("session_sync", {
    p_canvas_id: canvasId,
    p_selected_ids: selectedIds,
    p_phase: phase,
    p_zoom: zoom,
  }).catch(() => {}); // silent fail — session is ephemeral
}

/** Poll toast from PG session */
async function pollToast(canvasId: string) {
  const { data } = await supabase
    .from("session")
    .select("toast")
    .eq("canvas_id", canvasId)
    .limit(1)
    .single();

  if (data?.toast && data.toast.text) {
    store.getState().showToast(data.toast.text, data.toast.level, data.toast.duration);
    // Clear toast in PG
    await supabase
      .from("session")
      .update({ toast: null })
      .eq("canvas_id", canvasId);
  }
}

/** ---- CRUD via PostgREST ---- */

export async function addElement(canvasId: string, type: string, props: Record<string, unknown>) {
  const { data } = await supabase.rpc("element_add", {
    p_canvas_id: canvasId,
    p_type: type,
    p_sort_order: 0,
    p_props: props,
  });
  return data;
}

export async function updateElement(elementId: string, props: Record<string, unknown>) {
  await supabase.rpc("element_update", {
    p_element_id: elementId,
    p_props_patch: props,
  });
}

export async function deleteElement(elementId: string) {
  await supabase.rpc("element_delete", {
    p_element_id: elementId,
  });
}

export async function loadAssets() {
  const { data } = await supabase
    .from("asset")
    .select("id, filename, path, thumb_path, title, description, tags, status")
    .order("created_at", { ascending: false });
  store.getState().setAssets(data ?? []);
}
