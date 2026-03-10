/**
 * pgm deployer — checks dependencies and applies module SQL to a live
 * PostgreSQL database in dependency-resolved order.
 */

import fs from "fs/promises";
import path from "path";
import pg from "pg";
import type { ModuleManifest, InstallPlan } from "./resolver.js";

// --- Check types ---

export interface CheckItem {
  kind: "schema" | "extension";
  name: string;
  required_by: string;
  present: boolean;
}

export interface CheckResult {
  module: string;
  version: string;
  checks: CheckItem[];
  ok: boolean;
}

// --- Deploy types ---

export interface DeployResult {
  module: string;
  version: string;
  files: { name: string; ok: boolean; error?: string }[];
  ok: boolean;
}

// --- Pre-deploy check ---

export async function checkModules(
  plan: InstallPlan,
  connectionString: string,
  only?: string,
): Promise<CheckResult[]> {
  const client = new pg.Client({ connectionString });
  await client.connect();

  try {
    // Query all existing schemas and extensions in one shot
    const { rows: schemaRows } = await client.query<{ nspname: string }>(
      `SELECT nspname FROM pg_namespace`,
    );
    const existingSchemas = new Set(schemaRows.map((r) => r.nspname));

    const { rows: extRows } = await client.query<{ extname: string }>(
      `SELECT extname FROM pg_extension`,
    );
    const existingExtensions = new Set(extRows.map((r) => r.extname));

    // Track schemas that will be created by modules earlier in the plan
    const willCreate = new Set<string>();

    const results: CheckResult[] = [];

    for (const manifest of plan.order) {
      if (only && manifest.name !== only) {
        // Skipped modules must already exist in DB — don't assume they will be created
        continue;
      }

      const checks: CheckItem[] = [];

      // Check extensions required by this module
      for (const ext of manifest.extensions) {
        checks.push({
          kind: "extension",
          name: ext,
          required_by: manifest.name,
          present: existingExtensions.has(ext),
        });
      }

      // Check dependency schemas (from other modules this one depends on)
      for (const dep of manifest.dependencies) {
        const depManifest = plan.order.find((m) => m.name === dep);
        if (!depManifest) continue;

        const depSchema = depManifest.schemas.public;
        if (depSchema) {
          checks.push({
            kind: "schema",
            name: depSchema,
            required_by: manifest.name,
            present: existingSchemas.has(depSchema) || willCreate.has(depSchema),
          });
        }
      }

      const ok = checks.every((c) => c.present);
      results.push({ module: manifest.name, version: manifest.version, checks, ok });

      // Register what this module will create (for downstream checks)
      if (manifest.schemas.public) willCreate.add(manifest.schemas.public);
      if (manifest.schemas.private) willCreate.add(manifest.schemas.private);
    }

    return results;
  } finally {
    await client.end();
  }
}

// --- Deploy ---

export async function deployModules(
  modulesDir: string,
  plan: InstallPlan,
  connectionString: string,
  only?: string,
): Promise<DeployResult[]> {
  const client = new pg.Client({ connectionString });
  await client.connect();

  const results: DeployResult[] = [];

  try {
    for (const manifest of plan.order) {
      if (only && manifest.name !== only) continue;

      const result = await deployModule(client, modulesDir, manifest);
      results.push(result);

      if (!result.ok) {
        // Stop on first failure — downstream modules depend on this one
        break;
      }
    }
  } finally {
    await client.end();
  }

  return results;
}

async function deployModule(
  client: pg.Client,
  modulesDir: string,
  manifest: ModuleManifest,
): Promise<DeployResult> {
  const moduleDir = path.join(modulesDir, manifest.name);
  const files: DeployResult["files"] = [];

  // Install required extensions
  for (const ext of manifest.extensions) {
    try {
      await client.query(`CREATE EXTENSION IF NOT EXISTS ${ext}`);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      files.push({ name: `extension:${ext}`, ok: false, error: msg });
      return { module: manifest.name, version: manifest.version, files, ok: false };
    }
  }

  for (const sqlFile of manifest.sql) {
    const src = path.join(moduleDir, sqlFile);
    const basename = path.basename(sqlFile);

    let content: string;
    try {
      content = await fs.readFile(src, "utf-8");
    } catch {
      files.push({ name: basename, ok: false, error: "file not found" });
      return { module: manifest.name, version: manifest.version, files, ok: false };
    }

    try {
      await client.query(content);
      files.push({ name: basename, ok: true });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      files.push({ name: basename, ok: false, error: msg });
      return { module: manifest.name, version: manifest.version, files, ok: false };
    }
  }

  // Apply GRANTs
  for (const [role, schemas] of Object.entries(manifest.grants ?? {})) {
    for (const schema of schemas) {
      try {
        await client.query(`GRANT USAGE ON SCHEMA ${schema} TO ${role}`);
        await client.query(`GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${schema} TO ${role}`);
      } catch {
        // Role might not exist yet — non-fatal
      }
    }
  }

  return { module: manifest.name, version: manifest.version, files, ok: true };
}
