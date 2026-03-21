// ============================================================
// APP — entry point (Zustand + Supabase Realtime)
// ============================================================

// @ts-nocheck

import "./styles/tokens.css";
import "./styles/loader.css";
import "./styles/menubar.css";

// Imperative mode — Zustand + D3 + legacy DOM
import { store, guardMiddleware, subscribeToSlices } from "./store/index.js";
import { initToast } from "./toast.js";
import { initZoom } from "./zoom.js";
import { initEvents } from "./events.js";
import { initWs } from "./ws.js";
import { render } from "./render.js";
import { renderUI } from "./ui.js";
import { initImageEditor } from "./image-editor.js";
import * as sync from "./supabase-sync.js";

export interface MountConfig {
  url: string;
  key: string;
  canvasId?: string;
}

/**
 * Mount illustrator — always uses imperative mode.
 * Works both in pgView shell and standalone.
 */
export function mount(config: MountConfig) {
  mountLegacy(config);
}

/**
 * Legacy standalone mode — imperative DOM manipulation.
 * Used when loaded directly (localhost:3333) without pgView shell.
 */
function mountLegacy(config: MountConfig) {
  store.use(guardMiddleware);
  subscribeToSlices(["doc", "ui"], () => render());
  subscribeToSlices(["doc", "ui"], () => renderUI());

  document.fonts.ready.then(() => {
    document.getElementById('loader')?.classList.add('fonts-ready');
  });

  initToast();
  initZoom();
  initEvents();
  initWs(config);
  initImageEditor();
  sync.loadAssets();
}

// Auto-mount when loaded standalone (not via pgView shell)
if (!(window as any).__PGV_CONFIG__) {
  const url = (window as any).__SUPABASE_URL__ || "http://localhost:54321";
  const key = (window as any).__SUPABASE_KEY__ || "";
  const params = new URLSearchParams(window.location.search);
  const canvasId = params.get("canvas_id") || params.get("p_id") || undefined;
  mountLegacy({ url, key, canvasId });
}
