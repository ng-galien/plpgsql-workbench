// ============================================================
// APP — entry point (Zustand + Supabase Realtime)
// ============================================================

// @ts-nocheck

import "./styles/tokens.css";
import "./styles/loader.css";
import "./styles/menubar.css";

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

export function mount(config: MountConfig) {
  // Register state machine guards (no-op in Zustand bridge)
  store.use(guardMiddleware);

  // Subscriptions — re-render on state changes
  subscribeToSlices(["doc", "ui"], () => render());
  subscribeToSlices(["doc", "ui"], () => renderUI());

  // Loader
  document.fonts.ready.then(() => {
    document.getElementById('loader')?.classList.add('fonts-ready');
  });

  // Init
  initToast();
  initZoom();
  initEvents();
  initWs(config);
  initImageEditor();

  // Load assets from Supabase
  sync.loadAssets();
}

// Auto-mount when loaded standalone (not via pgView shell)
if (!(window as any).__PGV_CONFIG__) {
  const url = (window as any).__SUPABASE_URL__ || "http://localhost:54321";
  const key = (window as any).__SUPABASE_KEY__ || "";
  const params = new URLSearchParams(window.location.search);
  const canvasId = params.get("canvas_id") || params.get("p_id") || undefined;
  mount({ url, key, canvasId });
}
