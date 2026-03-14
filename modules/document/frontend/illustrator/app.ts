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
initWs();
initImageEditor();

// Load assets from Supabase
sync.loadAssets();
