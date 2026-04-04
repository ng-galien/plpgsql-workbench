import fsSync from "node:fs";
import path from "node:path";
import type { PluginManifest } from "../core/plugin-registry.js";
import { PACK_TO_PLUGINS } from "../plugins/index.js";

export interface WorkbenchConfig {
  name: string;
  packs?: string[];
  plugins?: Record<string, Record<string, unknown>>;
  connection?: string;
  port?: number;
}

export function loadConfig(log: { info: (...args: any[]) => void; warn: (...args: any[]) => void }): WorkbenchConfig {
  const configPath = process.env.WORKBENCH_CONFIG;
  if (configPath) {
    const resolved = path.resolve(configPath);
    const raw = JSON.parse(fsSync.readFileSync(resolved, "utf-8"));
    log.info({ config: resolved, app: raw.name }, "Loaded app config");
    return raw;
  }
  return { name: "dev" };
}

export function resolveManifest(config: WorkbenchConfig, log: { warn: (...args: any[]) => void }): PluginManifest {
  if (config.plugins) {
    return { plugins: config.plugins };
  }
  const packNames = config.packs ?? Object.keys(PACK_TO_PLUGINS);
  const plugins: Record<string, Record<string, unknown>> = {};
  for (const name of packNames) {
    const mapped = PACK_TO_PLUGINS[name];
    if (!mapped) {
      log.warn({ pack: name }, "Unknown pack in config, skipping");
      continue;
    }
    for (const plugin of mapped) {
      if (!plugins[plugin.id]) plugins[plugin.id] = {};
    }
  }
  return { plugins };
}
