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
  kind: "schema" | "extension" | "conflict" | "grant";
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
  const results: CheckResult[] = [];

  // --- Static checks (no DB needed) ---

  // 1. Schema ownership conflicts: no schema claimed by two modules
  const schemaOwners = new Map<string, string>(); // schema → module name
  for (const manifest of plan.order) {
    for (const schema of [manifest.schemas.public, manifest.schemas.private].filter(Boolean) as string[]) {
      const existing = schemaOwners.get(schema);
      if (existing && existing !== manifest.name) {
        // Both modules claim this schema — record conflict on both
        const conflictItem: CheckItem = {
          kind: "conflict",
          name: schema,
          required_by: `${manifest.name} vs ${existing}`,
          present: false,
        };
        // Add to current module's result (will be created below)
        const existingResult = results.find((r) => r.module === existing);
        if (existingResult) {
          existingResult.checks.push(conflictItem);
          existingResult.ok = false;
        }
      }
      schemaOwners.set(schema, manifest.name);
    }
  }

  // 2. Grants reference only owned schemas
  for (const manifest of plan.order) {
    const ownedSchemas = new Set<string>();
    if (manifest.schemas.public) ownedSchemas.add(manifest.schemas.public);
    if (manifest.schemas.private) ownedSchemas.add(manifest.schemas.private);
    // Test/QA schemas are also owned by convention
    if (manifest.schemas.public) {
      ownedSchemas.add(`${manifest.schemas.public}_ut`);
      ownedSchemas.add(`${manifest.schemas.public}_it`);
      ownedSchemas.add(`${manifest.schemas.public}_qa`);
    }

    const grantChecks: CheckItem[] = [];
    for (const [, schemas] of Object.entries(manifest.grants ?? {})) {
      for (const schema of schemas) {
        if (!ownedSchemas.has(schema)) {
          grantChecks.push({
            kind: "grant",
            name: schema,
            required_by: manifest.name,
            present: false,
          });
        }
      }
    }

    // If there were conflicts from step 1, they're already added
    const existingResult = results.find((r) => r.module === manifest.name);
    if (existingResult) {
      existingResult.checks.push(...grantChecks);
      if (grantChecks.some((c) => !c.present)) existingResult.ok = false;
    } else if (grantChecks.length > 0) {
      results.push({
        module: manifest.name,
        version: manifest.version,
        checks: grantChecks,
        ok: grantChecks.every((c) => c.present),
      });
    }
  }

  // --- DB checks ---

  const client = new pg.Client({ connectionString });
  await client.connect();

  try {
    const { rows: schemaRows } = await client.query<{ nspname: string }>(
      `SELECT nspname FROM pg_namespace`,
    );
    const existingSchemas = new Set(schemaRows.map((r) => r.nspname));

    // Check available extensions (can be installed), not just installed ones
    const { rows: availRows } = await client.query<{ name: string }>(
      `SELECT name FROM pg_available_extensions`,
    );
    const availableExtensions = new Set(availRows.map((r) => r.name));

    const { rows: extRows } = await client.query<{ extname: string }>(
      `SELECT extname FROM pg_extension`,
    );
    const installedExtensions = new Set(extRows.map((r) => r.extname));

    // Track what earlier modules in the plan will provide
    const willCreate = new Set<string>();
    const willInstall = new Set<string>();

    for (const manifest of plan.order) {
      if (only && manifest.name !== only) continue;

      const checks: CheckItem[] = [];

      // Check extensions: available on server (or already installed, or will be installed upstream)
      for (const ext of manifest.extensions) {
        const available = availableExtensions.has(ext)
          || installedExtensions.has(ext)
          || willInstall.has(ext);
        checks.push({
          kind: "extension",
          name: ext,
          required_by: manifest.name,
          present: available,
        });
      }

      // Check dependency schemas
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

      // Merge with any static checks already recorded
      const existingResult = results.find((r) => r.module === manifest.name);
      if (existingResult) {
        existingResult.checks.push(...checks);
        if (checks.some((c) => !c.present)) existingResult.ok = false;
      } else {
        const ok = checks.every((c) => c.present);
        results.push({ module: manifest.name, version: manifest.version, checks, ok });
      }

      // Register what this module provides for downstream checks
      if (manifest.schemas.public) willCreate.add(manifest.schemas.public);
      if (manifest.schemas.private) willCreate.add(manifest.schemas.private);
      for (const ext of manifest.extensions) willInstall.add(ext);
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

  const qi = (id: string) => `"${id.replace(/"/g, '""')}"`;

  // Wrap entire module in a transaction for atomicity
  await client.query("BEGIN");

  try {
    // Install required extensions
    for (const ext of manifest.extensions) {
      try {
        await client.query(`CREATE EXTENSION IF NOT EXISTS ${qi(ext)}`);
      } catch (err: unknown) {
        await client.query("ROLLBACK");
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
        await client.query("ROLLBACK");
        files.push({ name: basename, ok: false, error: "file not found" });
        return { module: manifest.name, version: manifest.version, files, ok: false };
      }

      try {
        await client.query(content);
        files.push({ name: basename, ok: true });
      } catch (err: unknown) {
        await client.query("ROLLBACK");
        const msg = err instanceof Error ? err.message : String(err);
        files.push({ name: basename, ok: false, error: msg });
        return { module: manifest.name, version: manifest.version, files, ok: false };
      }
    }

    // Apply GRANTs
    for (const [role, schemas] of Object.entries(manifest.grants ?? {})) {
      for (const schema of schemas) {
        try {
          await client.query(`GRANT USAGE ON SCHEMA ${qi(schema)} TO ${qi(role)}`);
          await client.query(`GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${qi(schema)} TO ${qi(role)}`);
        } catch {
          // Role might not exist yet — non-fatal
        }
      }
    }

    await client.query("COMMIT");
  } catch (err: unknown) {
    await client.query("ROLLBACK").catch(() => {});
    throw err;
  }

  return { module: manifest.name, version: manifest.version, files, ok: true };
}
