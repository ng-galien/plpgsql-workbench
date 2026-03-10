/**
 * pgm resolver — reads module.json manifests, resolves dependencies (topo sort),
 * and produces an ordered install plan.
 */

import fs from "fs/promises";
import path from "path";

// --- Types ---

export interface ModuleManifest {
  name: string;
  version: string;
  description: string;
  schemas: { public: string | null; private: string | null };
  dependencies: string[];
  extensions: string[];
  sql: string[];
  assets: { frontend?: string[]; scripts?: string[]; styles?: string[] };
  grants: Record<string, string[]>;
  docker?: { image: string; note?: string };
}

export interface AppConfig {
  name: string;
  modules?: string[];
  packs?: string[];
  connection?: string;
  port?: number;
}

// --- Workspace discovery ---

/**
 * Walk up from `startDir` to find the workspace root (contains `modules/`).
 */
export async function findWorkspaceRoot(startDir: string): Promise<string> {
  let dir = path.resolve(startDir);
  for (let i = 0; i < 10; i++) {
    try {
      await fs.access(path.join(dir, "modules"));
      return dir;
    } catch {
      const parent = path.dirname(dir);
      if (parent === dir) break;
      dir = parent;
    }
  }
  throw new Error(`Cannot find workspace root (no modules/ directory found from ${startDir})`);
}

/**
 * Find the app root (contains `workbench.json`) starting from `startDir`.
 */
export async function findAppRoot(startDir: string): Promise<string> {
  let dir = path.resolve(startDir);
  for (let i = 0; i < 10; i++) {
    try {
      await fs.access(path.join(dir, "workbench.json"));
      return dir;
    } catch {
      const parent = path.dirname(dir);
      if (parent === dir) break;
      dir = parent;
    }
  }
  throw new Error(`Cannot find app root (no workbench.json found from ${startDir})`);
}

// --- Manifest loading ---

export async function loadManifest(modulesDir: string, name: string): Promise<ModuleManifest> {
  const manifestPath = path.join(modulesDir, name, "module.json");
  try {
    const raw = await fs.readFile(manifestPath, "utf-8");
    return JSON.parse(raw) as ModuleManifest;
  } catch {
    throw new Error(`Module '${name}' not found at ${manifestPath}`);
  }
}

export async function loadAppConfig(appDir: string): Promise<AppConfig> {
  const configPath = path.join(appDir, "workbench.json");
  const raw = await fs.readFile(configPath, "utf-8");
  return JSON.parse(raw) as AppConfig;
}

export async function saveAppConfig(appDir: string, config: AppConfig): Promise<void> {
  await fs.writeFile(path.join(appDir, "workbench.json"), JSON.stringify(config, null, 2) + "\n", "utf-8");
}

// --- List available modules ---

export async function listAvailableModules(modulesDir: string): Promise<string[]> {
  const entries = await fs.readdir(modulesDir, { withFileTypes: true });
  const modules: string[] = [];
  for (const entry of entries) {
    if (entry.isDirectory()) {
      try {
        await fs.access(path.join(modulesDir, entry.name, "module.json"));
        modules.push(entry.name);
      } catch {
        // not a module
      }
    }
  }
  return modules.sort();
}

// --- Dependency resolution (topological sort) ---

export interface InstallPlan {
  order: ModuleManifest[];
  edges: { from: string; to: string }[];
}

export async function resolve(modulesDir: string, requested: string[]): Promise<InstallPlan> {
  const manifests = new Map<string, ModuleManifest>();
  const edges: { from: string; to: string }[] = [];

  // Recursively load all required manifests
  async function loadDeps(name: string): Promise<void> {
    if (manifests.has(name)) return;
    const manifest = await loadManifest(modulesDir, name);
    manifests.set(name, manifest);
    for (const dep of manifest.dependencies) {
      edges.push({ from: name, to: dep });
      await loadDeps(dep);
    }
  }

  for (const name of requested) {
    await loadDeps(name);
  }

  // Topological sort (Kahn's algorithm)
  const inDegree = new Map<string, number>();
  const graph = new Map<string, string[]>(); // dep → [dependents]

  for (const name of manifests.keys()) {
    inDegree.set(name, 0);
    graph.set(name, []);
  }

  for (const { from, to } of edges) {
    inDegree.set(from, (inDegree.get(from) ?? 0) + 1);
    graph.get(to)!.push(from);
  }

  const queue: string[] = [];
  for (const [name, deg] of inDegree) {
    if (deg === 0) queue.push(name);
  }
  queue.sort();

  const order: ModuleManifest[] = [];
  while (queue.length > 0) {
    const name = queue.shift()!;
    order.push(manifests.get(name)!);
    for (const dependent of graph.get(name) ?? []) {
      const deg = (inDegree.get(dependent) ?? 1) - 1;
      inDegree.set(dependent, deg);
      if (deg === 0) {
        // Insert sorted
        const idx = queue.findIndex((q) => q.localeCompare(dependent) > 0);
        queue.splice(idx === -1 ? queue.length : idx, 0, dependent);
      }
    }
  }

  // Circular deps: append remaining
  if (order.length < manifests.size) {
    for (const [, manifest] of manifests) {
      if (!order.includes(manifest)) {
        order.push(manifest);
      }
    }
  }

  return { order, edges };
}
