import type { Plugin } from "../core/plugin.js";
import { docmanPlugin } from "./docman.js";
import { docstorePlugin } from "./docstore.js";
import { googlePlugin } from "./google.js";
import { illustratorPlugin } from "./illustrator.js";
import { pgDatabasePlugin } from "./pg-database.js";
import { pgFunctionsPlugin } from "./pg-functions.js";
import { pgMessagingPlugin } from "./pg-messaging.js";
import { pgModulesPlugin } from "./pg-modules.js";
import { pgNavigationPlugin } from "./pg-navigation.js";
import { pgOperationsPlugin } from "./pg-operations.js";
import { pgRuntimePlugin } from "./pg-runtime.js";

/** All builtin plugins in dependency-safe order. */
export const ALL_PLUGINS: Plugin[] = [
  // Infrastructure (no requires)
  pgDatabasePlugin,
  // Core platform (requires withClient)
  pgFunctionsPlugin,
  pgNavigationPlugin,
  pgModulesPlugin, // registers moduleRegistry + workspaceRoot
  pgRuntimePlugin, // requires workspaceRoot from pg-modules
  pgMessagingPlugin,
  pgOperationsPlugin,
  // Integrations
  docstorePlugin,
  googlePlugin, // provides "gmail" capability
  docmanPlugin, // uses "gmail" capability if present
  illustratorPlugin,
];

/** Preset: all pg-* plugins (platform core). */
export const PLATFORM_PLUGINS: Plugin[] = [
  pgDatabasePlugin,
  pgFunctionsPlugin,
  pgNavigationPlugin,
  pgModulesPlugin,
  pgRuntimePlugin,
  pgMessagingPlugin,
  pgOperationsPlugin,
];

/** Map old pack names to plugin sets for backward compat. */
export const PACK_TO_PLUGINS: Record<string, Plugin[]> = {
  plpgsql: PLATFORM_PLUGINS,
  docstore: [docstorePlugin],
  google: [googlePlugin],
  docman: [docmanPlugin],
  illustrator: [illustratorPlugin],
};
