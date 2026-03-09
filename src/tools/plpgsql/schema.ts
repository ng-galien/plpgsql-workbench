import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import fs from "fs/promises";
import path from "path";
import crypto from "crypto";
import { execFile } from "child_process";

function resolveDir(dir: string): string {
  if (path.isAbsolute(dir)) return dir;
  return path.resolve(process.cwd(), dir);
}

/** Get current git commit hash, or null if not in a repo */
function gitCommit(): Promise<string | null> {
  return new Promise((resolve) => {
    execFile("git", ["rev-parse", "--short", "HEAD"], { cwd: process.cwd() }, (err, stdout) => {
      if (err) return resolve(null);
      resolve(stdout.trim() || null);
    });
  });
}

async function ensureMigrationTable(client: DbClient): Promise<void> {
  await client.query(`CREATE SCHEMA IF NOT EXISTS workbench`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS workbench.applied_migration (
      filename text PRIMARY KEY,
      hash text NOT NULL,
      commit_hash text,
      applied_at timestamptz DEFAULT now()
    )
  `);
}

interface MigrationResult {
  filename: string;
  status: "applied" | "skipped" | "changed" | "error";
  message?: string;
}

async function applyMigrations(
  client: DbClient,
  dir: string,
  force: boolean,
): Promise<string> {
  const resolved = resolveDir(dir);

  let entries: string[];
  try {
    entries = await fs.readdir(resolved);
  } catch {
    return `problem: directory not found: ${resolved}\nwhere: pg_schema\nfix_hint: check the path argument`;
  }

  const sqlFiles = entries.filter((f) => f.endsWith(".sql")).sort();
  if (sqlFiles.length === 0) {
    return `no .sql files in ${resolved}`;
  }

  await ensureMigrationTable(client);

  const applied = new Map<string, string>();
  const { rows } = await client.query<{ filename: string; hash: string }>(
    `SELECT filename, hash FROM workbench.applied_migration`,
  );
  for (const r of rows) applied.set(r.filename, r.hash);

  const commit = await gitCommit();
  const results: MigrationResult[] = [];

  for (const file of sqlFiles) {
    const filePath = path.join(resolved, file);
    const content = await fs.readFile(filePath, "utf-8");
    const hash = crypto.createHash("sha256").update(content).digest("hex").slice(0, 16);

    if (applied.has(file)) {
      if (applied.get(file) === hash) {
        results.push({ filename: file, status: "skipped" });
        continue;
      } else if (!force) {
        results.push({ filename: file, status: "changed", message: "file changed since last apply (hash mismatch)" });
        continue;
      }
      // force: delete old tracking so it re-applies
      await client.query(`DELETE FROM workbench.applied_migration WHERE filename = $1`, [file]);
    }

    try {
      await client.query("BEGIN");
      await client.query(content);
      await client.query("COMMIT");
    } catch (err: unknown) {
      await client.query("ROLLBACK").catch(() => {});
      const msg = err instanceof Error ? err.message : String(err);
      results.push({ filename: file, status: "error", message: msg });
      continue;
    }

    await client.query(
      `INSERT INTO workbench.applied_migration (filename, hash, commit_hash) VALUES ($1, $2, $3)
       ON CONFLICT (filename) DO UPDATE SET hash = $2, commit_hash = $3, applied_at = now()`,
      [file, hash, commit],
    );

    results.push({ filename: file, status: "applied" });
  }

  return formatResults(results, dir);
}

function formatResults(results: MigrationResult[], dir: string): string {
  const applied = results.filter((r) => r.status === "applied");
  const skipped = results.filter((r) => r.status === "skipped");
  const changed = results.filter((r) => r.status === "changed");
  const errors = results.filter((r) => r.status === "error");

  const parts: string[] = [];

  if (errors.length > 0) {
    parts.push(`✗ ${applied.length} applied, ${errors.length} failed (${dir})`);
  } else if (applied.length === 0) {
    parts.push(`✓ nothing to apply (${dir})`);
  } else {
    parts.push(`✓ ${applied.length} applied (${dir})`);
  }
  parts.push(`completeness: full`);
  parts.push("");

  for (const r of results) {
    switch (r.status) {
      case "applied":
        parts.push(`  ✓ ${r.filename}`);
        break;
      case "skipped":
        parts.push(`  - ${r.filename} (already applied)`);
        break;
      case "changed":
        parts.push(`  ⚠ ${r.filename} (${r.message})`);
        break;
      case "error":
        parts.push(`  ✗ ${r.filename}`);
        parts.push(`    problem: ${r.message}`);
        break;
    }
  }

  if (skipped.length > 0 && changed.length > 0) {
    parts.push("");
    parts.push(`${changed.length} file(s) changed since last apply — review and re-apply with force if intended`);
  }

  return parts.join("\n");
}

export function createSchemaTool({ withClient }: {
  withClient: WithClient;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_schema",
      description:
        "Apply pending DDL migration files to the database.\n" +
        "Executes .sql files in alphabetical order, each in its own transaction.\n" +
        "Tracks applied files to avoid re-running. Detects changed files.",
      schema: z.object({
        path: z.string().describe("Directory containing DDL migration .sql files (relative to project root or absolute)"),
        force: z
          .boolean()
          .optional()
          .default(false)
          .describe("Re-apply changed files instead of warning"),
      }),
    },
    handler: async (args, _extra) => {
      const dir = args.path as string;
      const force = (args.force as boolean | undefined) ?? false;

      return withClient(async (client) => {
        const result = await applyMigrations(client, dir, force);
        return text(result);
      });
    },
  };
}
