/**
 * Module registry — maps schemas to modules for auto-path resolution.
 * Used by MCP tools (pg_pack, pg_func_save) to know where to write.
 */

import fs from "fs/promises";
import path from "path";
import type { ModuleManifest } from "./resolver.js";

export interface ModuleMapping {
  module: string;
  modulePath: string;        // absolute path to module dir
  functionsFile: string;     // relative SQL file for pg_pack output
  schemas: string[];         // all schemas owned by this module
}

export interface ModuleRegistry {
  /** Resolve a list of schemas to a module. Returns null if no module owns ALL schemas. */
  resolve(schemas: string[]): ModuleMapping | null;
  /** Get the module path for pg_func_save given a schema. */
  savePath(schema: string): string | null;
}

export async function buildModuleRegistry(workspaceRoot: string): Promise<ModuleRegistry> {
  const modulesDir = path.join(workspaceRoot, "modules");
  const mappings: ModuleMapping[] = [];

  try {
    const entries = await fs.readdir(modulesDir, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const manifestPath = path.join(modulesDir, entry.name, "module.json");
      try {
        const raw = await fs.readFile(manifestPath, "utf-8");
        const manifest = JSON.parse(raw) as ModuleManifest;

        const schemas: string[] = [];
        if (manifest.schemas.public) schemas.push(manifest.schemas.public);
        if (manifest.schemas.private) schemas.push(manifest.schemas.private);
        // Also include test schemas by convention
        if (manifest.schemas.public) {
          schemas.push(`${manifest.schemas.public}_ut`);
          schemas.push(`${manifest.schemas.public}_it`);
        }

        const functionsFile = manifest.sql.find((f) => f.includes("functions")) ?? "";

        mappings.push({
          module: manifest.name,
          modulePath: path.join(modulesDir, entry.name),
          functionsFile,
          schemas,
        });
      } catch {
        // skip invalid modules
      }
    }
  } catch {
    // modules/ doesn't exist
  }

  return {
    resolve(schemas: string[]): ModuleMapping | null {
      // Find a module that owns ALL given schemas
      for (const m of mappings) {
        if (schemas.every((s) => m.schemas.includes(s))) {
          return m;
        }
      }
      return null;
    },

    savePath(schema: string): string | null {
      for (const m of mappings) {
        if (m.schemas.includes(schema)) {
          return path.join(m.modulePath, "sql");
        }
      }
      return null;
    },
  };
}
