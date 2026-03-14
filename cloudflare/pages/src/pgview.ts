/**
 * pgview.ts — pgView shell kernel
 *
 * Exported as IIFE global `pgv` via esbuild.
 * Entry point: registers Alpine components and re-exports all modules.
 */

// -- CSS modules --
import "./css/tokens.css";
import "./css/layout.css";
import "./css/components.css";
import "./css/table.css";
import "./css/overlays.css";
import "./css/canvas.css";
import "./css/widgets.css";
import "./css/print.css";

export type { PgvConfig } from "./config.js";
// -- Config & i18n --
export { getConfig } from "./config.js";
export type { EnhanceContext } from "./enhance.js";
// -- Enhance --
export { enhance, initTable, loadLazy, setEnhanceContext } from "./enhance.js";
export { loadI18n, t } from "./i18n.js";
// -- Realtime --
export { destroyAll, pgListen, pgRpc, supabase } from "./realtime.js";
export type { RouterCallbacks, RouterState } from "./router.js";
// -- Router --
export { go, handleError, initRouter, openFormDialog, post, render, renderHome, submitFormDialog } from "./router.js";
export type { AppModule, PgChangeHandler, PgChangePayload } from "./types.js";

// -- Shell --
import { createShellComponent } from "./shell.js";

export { createShellComponent };

// -- Plugins --
import { registerTable, setTableGoFn } from "./plugins/table.js";

export { loadIllustrator } from "./plugins/illustrator.js";
export { registerTable, setTableGoFn };

// Internal import for wiring
import { go } from "./router.js";

/**
 * Register the pgView shell + pgvTable Alpine components.
 * Called from index.html: pgv.registerShell(Alpine)
 */
export function registerShell(Alpine: AlpineStatic): void {
  // Flush any plugins registered before Alpine loaded
  const pgvGlobal = window.pgv;
  if (pgvGlobal?._flushPlugins) pgvGlobal._flushPlugins();

  // Register the main shell component
  Alpine.data("pgview", () => createShellComponent());

  // Register pgvTable and wire navigation
  registerTable(Alpine);
  setTableGoFn(go);
}
