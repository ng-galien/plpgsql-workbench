/**
 * plugins/illustrator.ts — Illustrator loader
 *
 * Detects data-illustrator marker in the DOM, hides pgView chrome,
 * loads D3 + app bundle, and boots the illustrator.
 */

import { getConfig } from "../config.js";

let _illustratorLoaded = false;

/**
 * Load and mount the illustrator app on the given canvas element.
 * Hides pgView chrome (nav, app bar) and loads dependencies if needed.
 */
export function loadIllustrator(canvasId: string): void {
  var cfg = getConfig();

  // Hide pgView chrome, go fullscreen
  var nav = document.querySelector("nav.container-fluid") as HTMLElement | null;
  if (nav) nav.style.display = "none";
  var appBar = document.getElementById("appBar");
  if (appBar) appBar.style.display = "none";
  var app = document.getElementById("app");
  if (app) {
    app.style.padding = "0";
    app.style.maxWidth = "none";
  }

  function boot() {
    var src = "/illustrator/app.js";
    (import(src) as Promise<{ mount: (config: { url: string; key: string; canvasId: string }) => void }>).then((m) => {
      m.mount({ url: cfg.supabaseUrl, key: cfg.supabaseKey, canvasId: canvasId });
    });
  }

  if (_illustratorLoaded) {
    boot();
    return;
  }

  // Load app.css
  var css = document.createElement("link");
  css.rel = "stylesheet";
  css.href = "/illustrator/app.css";
  document.head.appendChild(css);

  if (typeof d3 === "undefined") {
    const d3s = document.createElement("script");
    d3s.src = "https://cdn.jsdelivr.net/npm/d3@7/dist/d3.min.js";
    d3s.onload = () => {
      _illustratorLoaded = true;
      boot();
    };
    document.head.appendChild(d3s);
  } else {
    _illustratorLoaded = true;
    boot();
  }
}
