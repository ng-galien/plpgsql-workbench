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
let supabase: SupabaseClient | null = null;  // schema: document
let channel: any = null;
let sessionSyncTimer: any = null;
let toastPollTimer: any = null;

/** Initialize Supabase client + subscribe to canvas changes */
export function init(url: string, key: string, canvasId: string) {
  supabaseUrl = url;
  supabaseKey = key;

  console.log("[sync] init", { url: supabaseUrl, canvasId });
  supabase = createClient(supabaseUrl, supabaseKey, {
    db: { schema: "document" },
  });

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
      console.log("[realtime] INSERT", payload.new.type, payload.new.name ?? payload.new.id?.slice(0,6));
      const el = rowToElement(payload.new);
      store.getState().addElement(el);
    })
    .on("postgres_changes", {
      event: "UPDATE",
      schema: "document",
      table: "element",
      filter: `canvas_id=eq.${canvasId}`,
    }, (payload: any) => {
      console.log("[realtime] UPDATE", payload.new.type, payload.new.name ?? payload.new.id?.slice(0,6));
      const el = rowToElement(payload.new);
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
      console.log("[realtime] DELETE", payload.old.id?.slice(0,6));
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
    console.error("[sync] Canvas not found:", canvasId);
    return;
  }
  console.log("[sync] canvas loaded:", canvas.name, canvas.id);

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

  const mapped = (elements ?? []).map(rowToElement);
  console.log("[sync] elements loaded:", mapped.length, mapped.map((e: any) => `${e.type}:${e.name ?? e.id?.slice(0,6)}`));
  store.getState().setElements(mapped);

  // Load doc list
  const { data: docList } = await supabase
    .from("canvas")
    .select("id, name, category, format")
    .order("updated_at", { ascending: false });
  console.log("[sync] doc list:", (docList ?? []).length, "canvases");
  store.getState().setDocList(docList ?? []);

  // Hide loader after first load
  const loader = document.getElementById("loader");
  if (loader && !loader.classList.contains("hidden")) {
    setTimeout(() => loader.classList.add("hidden"), 2600);
  }
}

/** Convert PG row to Element — flatten props into the element object.
 * PG stores: { x, y, fill, props: { content, fontSize, fontFamily, ... } }
 * Renderer expects: { x, y, fill, text, fontSize, fontFamily, ... } (flat)
 */
function rowToElement(row: any): any {
  const props = row.props ?? {};
  return {
    id: row.id,
    type: row.type,
    name: row.name ?? props.name,
    parent_id: row.parent_id,
    sort_order: row.sort_order,
    // Geometry from columns
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
    // Visual from columns
    opacity: row.opacity ?? 1,
    rotation: row.rotation ?? 0,
    fill: row.fill,
    stroke: row.stroke,
    strokeWidth: row.stroke_width ?? props.stroke_width ?? 0,
    // Text props (renderer expects .text not .content)
    text: props.content ?? props.text ?? "",
    fontSize: props.fontSize ?? 8,
    fontFamily: props.fontFamily ?? "Libre Baskerville",
    fontWeight: props.fontWeight ?? "bold",
    fontStyle: props.fontStyle ?? "normal",
    textAnchor: props.textAnchor ?? "start",
    maxWidth: props.maxWidth ?? null,
    // Rect
    rx: props.rx ?? 0,
    // Image
    path: props.path ?? null,
    asset_id: row.asset_id ?? props.asset_id ?? null,
    objectFit: props.objectFit ?? "cover",
    cropX: props.cropX ?? 0.5,
    cropY: props.cropY ?? 0.5,
    cropZoom: props.cropZoom ?? 1,
    naturalWidth: props.naturalWidth ?? null,
    naturalHeight: props.naturalHeight ?? null,
    // All remaining props
    ...props,
  };
}

/** Sync ephemeral state to PG UNLOGGED session */
async function syncSession(canvasId: string, selectedIds: string[], phase: string, zoom: number) {
  const { error } = await supabase!.from("session").upsert({
    canvas_id: canvasId,
    user_id: "dev",
    tenant_id: "dev",
    selected_ids: selectedIds,
    phase,
    zoom,
    updated_at: new Date().toISOString(),
  }, { onConflict: "canvas_id,user_id" });
  if (error) console.warn("[sync:session]", error.message, error.details);
}

/** Poll toast from PG session */
async function pollToast(canvasId: string) {
  const { data, error } = await supabase!
    .from("session")
    .select("toast")
    .eq("canvas_id", canvasId)
    .limit(1)
    .maybeSingle();
  if (error) { console.warn("[sync:toast]", error.message); return; }
  if (data?.toast && data.toast.text) {
    store.getState().showToast(data.toast.text, data.toast.level, data.toast.duration);
    await supabase!.from("session").update({ toast: null }).eq("canvas_id", canvasId);
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
  if (!supabaseUrl) return;
  // Use fetch with Accept-Profile header to query the asset schema
  // without creating a second Supabase client
  try {
    const res = await fetch(`${supabaseUrl}/rest/v1/asset?select=id,filename,path,thumb_path,title,description,tags,status&order=created_at.desc`, {
      headers: {
        "apikey": supabaseKey,
        "Accept-Profile": "asset",
      },
    });
    if (res.ok) {
      const data = await res.json();
      store.getState().setAssets(data ?? []);
    }
  } catch (e) {
    console.warn("[sync:assets]", e);
  }
}
