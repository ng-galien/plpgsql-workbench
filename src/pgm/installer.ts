/**
 * pgm installer — copies module SQL + assets into an app directory
 * with proper slot numbering and ordering.
 */

import fs from "fs/promises";
import path from "path";
import type { InstallPlan } from "./resolver.js";

// --- Slot assignment ---
// 00 = extensions (pgv)
// 01 = roles (app-specific, never from a module)
// 02 = pgv framework SQL
// 05+ = other modules (one slot per module)

const PGV_SLOT = 2;
const MODULE_SLOT_START = 5;

interface CopyResult {
  module: string;
  version: string;
  files: string[];
}

export async function installModules(
  modulesDir: string,
  appDir: string,
  plan: InstallPlan,
): Promise<CopyResult[]> {
  const results: CopyResult[] = [];
  let nextSlot = MODULE_SLOT_START;

  for (const manifest of plan.order) {
    const moduleDir = path.join(modulesDir, manifest.name);
    const files: string[] = [];

    // --- SQL files ---
    for (const sqlFile of manifest.sql) {
      const src = path.join(moduleDir, sqlFile);
      const basename = path.basename(sqlFile);

      if (!await fileExists(src)) {
        continue;
      }

      let targetName: string;
      if (manifest.name === "pgv") {
        // pgv has reserved slots
        switch (basename) {
          case "00-extensions.sql": targetName = "00-extensions.sql"; break;
          case "pgv.sql":           targetName = "02-pgv.sql"; break;
          default:                  targetName = `0${PGV_SLOT}-${basename}`; break;
        }
      } else {
        // Other modules get their slot
        const slot = String(nextSlot).padStart(2, "0");
        switch (basename) {
          case "00-extensions.sql": targetName = `${slot}-${manifest.name}-extensions.sql`; break;
          default:                  targetName = `${slot}-${manifest.name}-${basename}`; break;
        }
      }

      await fs.copyFile(src, path.join(appDir, "sql", targetName));
      files.push(`sql/${targetName}`);
    }

    // --- Frontend assets ---
    const frontendAssets = manifest.assets?.frontend ?? [];
    for (const assetFile of frontendAssets) {
      const src = path.join(moduleDir, assetFile);
      const basename = path.basename(assetFile);

      if (!await fileExists(src)) {
        continue;
      }

      await fs.copyFile(src, path.join(appDir, "frontend", basename));
      files.push(`frontend/${basename}`);
    }

    results.push({ module: manifest.name, version: manifest.version, files });

    if (manifest.name !== "pgv") {
      nextSlot++;
    }
  }

  return results;
}

// --- Helpers ---

async function fileExists(p: string): Promise<boolean> {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}
