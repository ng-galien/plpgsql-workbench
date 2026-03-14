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

// -- Config & i18n --
export { getConfig } from "./config.js";
export type { PgvConfig } from "./config.js";
export { t, loadI18n } from "./i18n.js";

// -- Realtime --
export { supabase, pgListen, pgRpc, destroyAll } from "./realtime.js";
export type { PgChangePayload, PgChangeHandler } from "./types.js";
export type { AppModule } from "./types.js";

// -- Enhance --
export { enhance, initTable, loadLazy, setEnhanceContext } from "./enhance.js";
export type { EnhanceContext } from "./enhance.js";

// -- Router --
export { go, post, render, handleError, renderHome, initRouter, openFormDialog, submitFormDialog } from "./router.js";
export type { RouterState, RouterCallbacks } from "./router.js";

// -- Shell --
import { createShellComponent } from "./shell.js";
export { createShellComponent };

// -- Plugins --
import { registerTable, setTableGoFn } from "./plugins/table.js";
export { registerTable, setTableGoFn };
export { loadIllustrator } from "./plugins/illustrator.js";

// Internal import for wiring
import { go } from "./router.js";

/**
 * Register the pgView shell + pgvTable Alpine components.
 * Called from index.html: pgv.registerShell(Alpine)
 */
export function registerShell(Alpine: any): void {
  // Flush any plugins registered before Alpine loaded
  var pgvGlobal = (window as any).pgv;
  if (pgvGlobal && pgvGlobal._flushPlugins) pgvGlobal._flushPlugins();

  // Register the main shell component
  Alpine.data('pgview', function() { return createShellComponent(); });

  // Register pgvTable and wire navigation
  registerTable(Alpine);
  setTableGoFn(go);
}
