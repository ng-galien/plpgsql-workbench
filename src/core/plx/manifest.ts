/**
 * PLX module manifest — minimal, PLX-first.
 * Legacy ModuleManifest lives in pgm/resolver.ts. This is the clean type.
 */

import fs from "node:fs/promises";
import path from "node:path";
import type { ModuleManifest } from "../pgm/resolver.js";

export interface PlxModuleManifest {
  name: string;
  version: string;
  description: string;
  plx: { entry: string; seed?: string };
  dependencies?: string[];
  extensions?: string[];
  grants?: Record<string, string[]>;
  private?: string;
}

/** Derive the public schema name (= module name by convention). */
export function plxSchema(manifest: PlxModuleManifest): string {
  return manifest.name;
}

/** Derive standard build file targets from module name. */
export function plxBuildTargets(name: string): { ddl: string; func: string; test: string } {
  return {
    ddl: `build/${name}.ddl.sql`,
    func: `build/${name}.func.sql`,
    test: `build/${name}_ut.func.sql`,
  };
}

/** Derive all schemas owned by a PLX module. */
export function plxSchemas(manifest: PlxModuleManifest): string[] {
  const pub = manifest.name;
  const schemas = [pub, `${pub}_ut`, `${pub}_it`];
  if (manifest.private) schemas.push(manifest.private);
  return schemas;
}

/** Load a PLX module manifest from module.json. Throws if plx.entry is missing. */
export async function loadPlxManifest(modulesDir: string, name: string): Promise<PlxModuleManifest> {
  const manifestPath = path.join(modulesDir, name, "module.json");
  let raw: string;
  try {
    raw = await fs.readFile(manifestPath, "utf-8");
  } catch {
    throw new Error(`Module '${name}' not found at ${manifestPath}`);
  }
  let manifest: PlxModuleManifest;
  try {
    manifest = JSON.parse(raw) as PlxModuleManifest;
  } catch {
    throw new Error(`Invalid JSON in ${manifestPath}`);
  }
  if (!manifest.plx?.entry) {
    throw new Error(`Module '${name}' is not a PLX module (missing plx.entry)`);
  }
  return manifest;
}

/** Extract PlxModuleManifest from a legacy ModuleManifest. */
export function fromModuleManifest(m: ModuleManifest): PlxModuleManifest {
  if (!m.plx?.entry) throw new Error(`Not a PLX module: ${m.name}`);
  return {
    name: m.name,
    version: m.version,
    description: m.description,
    plx: m.plx,
    dependencies: m.dependencies.length > 0 ? m.dependencies : undefined,
    extensions: m.extensions.length > 0 ? m.extensions : undefined,
    grants: Object.keys(m.grants).length > 0 ? m.grants : undefined,
    private: m.schemas.private ?? undefined,
  };
}

/** Adapter: convert PlxModuleManifest to legacy ModuleManifest for pgm consumers. */
export function toModuleManifest(plx: PlxModuleManifest): ModuleManifest {
  const targets = plxBuildTargets(plx.name);
  return {
    name: plx.name,
    version: plx.version,
    description: plx.description,
    schemas: {
      public: plx.name,
      private: plx.private ?? null,
    },
    dependencies: plx.dependencies ?? [],
    extensions: plx.extensions ?? [],
    sql: [targets.ddl, targets.func, targets.test],
    assets: {},
    grants: plx.grants ?? {},
    plx: plx.plx,
  };
}
