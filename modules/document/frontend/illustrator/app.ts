// ============================================================
// APP — entry point
// ============================================================

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
import { loadAssets } from "./photos.js";
import { initImageEditor } from "./image-editor.js";

// Register state machine guards
store.use(guardMiddleware);

// Subscriptions — replace the old render callback chain
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
loadAssets();
initImageEditor();
