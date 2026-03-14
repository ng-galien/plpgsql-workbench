/**
 * pgview.ts — pgView shell kernel
 *
 * Exported as IIFE global `pgv` via esbuild.
 * The Alpine component in index.html calls these modules.
 *
 * Progressive migration: modules extracted here are called from
 * the inline Alpine component. Over time, more code moves here.
 */

export { getConfig } from "./config.js";
export type { PgvConfig } from "./config.js";

export { t, loadI18n } from "./i18n.js";

export { supabase, pgListen, pgRpc, destroyAll } from "./realtime.js";
export type { PgChangePayload, PgChangeHandler } from "./types.js";
export type { AppModule } from "./types.js";
