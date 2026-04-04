/**
 * plugin-registry.ts — Build a DI container from explicit plugins.
 *
 * Replaces buildContainer() from container.ts.
 * Same Awilix mechanics, but plugins declare requires/capabilities
 * and contribute hook rules.
 */

import { type AwilixContainer, asValue, createContainer } from "awilix";
import type { ToolHandler } from "./container.js";
import { type HookRule, matchesToolPattern, type Plugin, type PluginConfig } from "./plugin.js";

// --- Types ---

export interface PluginManifest {
  /** Plugin id → config. Order determines registration order. */
  plugins: Record<string, PluginConfig>;
}

export interface PluginContainerResult {
  container: AwilixContainer;
  hookRules: HookRule[];
  loadedPlugins: string[];
}

// --- Builder ---

export function buildPluginContainer(manifest: PluginManifest, available: Plugin[]): PluginContainerResult {
  const container = createContainer({ strict: true });
  const hookRules: HookRule[] = [];
  const loadedPlugins: string[] = [];
  const capabilities = new Set<string>();

  // Register capabilities early so plugins can read them during register()
  container.register({ pluginCapabilities: asValue(capabilities) });

  // Index available plugins by id
  const byId = new Map<string, Plugin>();
  for (const plugin of available) {
    if (byId.has(plugin.id)) throw new Error(`Duplicate plugin id: ${plugin.id}`);
    byId.set(plugin.id, plugin);
  }

  // Register each requested plugin in manifest order
  for (const [id, config] of Object.entries(manifest.plugins)) {
    const plugin = byId.get(id);
    if (!plugin) throw new Error(`Unknown plugin: ${id}`);

    // Verify requires
    if (plugin.requires) {
      for (const dep of plugin.requires) {
        if (!container.registrations[dep]) {
          throw new Error(`Plugin "${id}" requires "${dep}" but it is not registered. Check plugin load order.`);
        }
      }
    }

    // Track capabilities before register() so downstream plugins can see them
    if (plugin.capabilities) {
      for (const cap of plugin.capabilities) capabilities.add(cap);
    }

    plugin.register(container, config);
    loadedPlugins.push(id);

    // Collect hooks
    if (plugin.hooks) {
      hookRules.push(...plugin.hooks());
    }
  }

  // Build tool registry (same *Tool scan as the old buildContainer)
  const registry = new Map<string, ToolHandler>();
  for (const name of Object.keys(container.registrations)) {
    if (!name.endsWith("Tool")) continue;
    const val = container.resolve(name);
    if (isToolHandler(val)) {
      registry.set(val.metadata.name, val);
    }
  }
  container.register({ toolRegistry: asValue(registry) });

  return { container, hookRules, loadedPlugins };
}

// --- Hook evaluation ---

export function evaluateHookRules(
  rules: HookRule[],
  toolName: string,
  ctx: Omit<import("./plugin.js").HookContext, "toolName">,
): import("./plugin.js").HookDecision | null {
  const fullCtx = { ...ctx, toolName };
  for (const rule of rules) {
    if (!matchesToolPattern(toolName, rule.toolPattern)) continue;
    const decision = rule.evaluate(fullCtx);
    if (decision) return decision;
  }
  return null;
}

// --- Guard ---

function isToolHandler(val: unknown): val is ToolHandler {
  if (typeof val !== "object" || val === null) return false;
  const candidate = val as Record<string, unknown>;
  const meta = candidate.metadata;
  return (
    typeof meta === "object" &&
    meta !== null &&
    typeof (meta as Record<string, unknown>).name === "string" &&
    typeof candidate.handler === "function"
  );
}
