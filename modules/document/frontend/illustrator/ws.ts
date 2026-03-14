/**
 * ws.ts — Rewritten to use Supabase sync instead of WebSocket.
 *
 * Same exports as before so all importers (render, events, props, etc.) work unchanged.
 * Under the hood: PostgREST RPC calls instead of wsSend().
 */

// @ts-nocheck

import { store, dispatch } from "./store/index.js";
import * as sync from "./supabase-sync.js";

let canvasId: string | null = null;

/** Initialize Supabase sync (replaces WebSocket connection) */
export function initWs(): void {
  const params = new URLSearchParams(window.location.search);
  canvasId = params.get("canvas_id") || params.get("p_id");

  if (!canvasId) {
    console.warn("No canvas_id in URL — waiting for doc load");
    return;
  }

  const url = (window as any).__SUPABASE_URL__ || "http://localhost:54321";
  const key = (window as any).__SUPABASE_KEY__ || "";

  sync.init(url, key, canvasId);
}

/** Send generic message — routes to appropriate Supabase call */
export function wsSend(msg: any): void {
  if (!canvasId) return;

  switch (msg.type) {
    case "update_element":
      sync.updateElement(msg.id, msg.props);
      break;
    case "delete_element":
      sync.deleteElement(msg.id);
      break;
    case "add_element":
      sync.addElement(canvasId, msg.element?.type ?? "rect", msg.element ?? {});
      break;
    case "paste_elements":
      for (const el of msg.elements ?? []) {
        sync.addElement(canvasId, el.type ?? "rect", el);
      }
      break;
    case "clear_canvas":
      break;
    case "save_document":
      break;
    case "load_document":
      sync.destroy();
      canvasId = msg.name;
      const url2 = (window as any).__SUPABASE_URL__ || "http://localhost:54321";
      const key2 = (window as any).__SUPABASE_KEY__ || "";
      sync.init(url2, key2, canvasId);
      break;
    case "reorder_element":
      break;
    case "select_element":
      dispatch({ type: "SELECT_ELEMENT", id: msg.id });
      break;
    case "select_asset":
      break;
    default:
      console.warn("wsSend unhandled:", msg.type);
  }
}

export function setSelection(id: string | null): void {
  dispatch({ type: "SELECT_ELEMENT", id });
}

export function sendUpdate(id: string, props: object): void { wsSend({ type: "update_element", id, props }); }
export function sendDelete(id: string): void { wsSend({ type: "delete_element", id }); }
export function sendClear(): void { wsSend({ type: "clear_canvas" }); }
export function sendDeleteDoc(name: string): void { wsSend({ type: "delete_document", name }); }
export function sendLoadDoc(name: string): void { wsSend({ type: "load_document", name }); }
export function sendSave(): void { /* PG persists immediately */ }
export function sendUpdateCanvas(props: object): void { wsSend({ type: "update_canvas", ...props }); }
export function sendUpdateMeta(props: object): void { wsSend({ type: "update_meta", ...props }); }
export function sendAddElement(element: any): void { wsSend({ type: "add_element", element }); }
export function sendPasteElements(elements: any[]): void { wsSend({ type: "paste_elements", elements }); }

export function onNextStateUpdate(): Promise<void> {
  return new Promise(resolve => {
    const unsub = store.subscribe(() => { unsub(); resolve(); });
    setTimeout(() => { unsub(); resolve(); }, 2000);
  });
}
