import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { text, withClient } from "../helpers.js";
import type { DbClient } from "../connection.js";
import fs from "fs/promises";
import path from "path";
import crypto from "crypto";
import { execFile } from "child_process";

/** Resolve relative paths from project root (parent of mcp-server/) */
function resolveDir(dir: string): string {
  if (path.isAbsolute(dir)) return dir;
  const root = process.env.WORKBENCH_ROOT ?? path.resolve(process.cwd(), "..");
  return path.resolve(root, dir);
}

/** Get current git commit hash, or null if not in a repo */
function gitCommit(): Promise<string | null> {
  return new Promise((resolve) => {
    const root = process.env.WORKBENCH_ROOT ?? path.resolve(process.cwd(), "..");
    execFile("git", ["rev-parse", "--short", "HEAD"], { cwd: root }, (err, stdout) => {
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

interface ApplyResult {
  filename: string;
  status: "applied" | "skipped" | "changed" | "error";
  message?: string;
}

async function applyFiles(
  client: DbClient,
  dir: string,
  track: boolean,
): Promise<string> {
  const resolved = resolveDir(dir);

  let entries: string[];
  try {
    entries = await fs.readdir(resolved);
  } catch {
    return `✗ directory not found: ${resolved}`;
  }

  const sqlFiles = entries.filter((f) => f.endsWith(".sql")).sort();
  if (sqlFiles.length === 0) {
    return `no .sql files in ${resolved}`;
  }

  if (track) {
    await ensureMigrationTable(client);
  }

  // Load already-applied migrations
  const applied = new Map<string, string>();
  if (track) {
    const { rows } = await client.query<{ filename: string; hash: string }>(
      `SELECT filename, hash FROM workbench.applied_migration`,
    );
    for (const r of rows) applied.set(r.filename, r.hash);
  }

  const commit = track ? await gitCommit() : null;
  const results: ApplyResult[] = [];

  for (const file of sqlFiles) {
    const filePath = path.join(resolved, file);
    const content = await fs.readFile(filePath, "utf-8");
    const hash = crypto.createHash("sha256").update(content).digest("hex").slice(0, 16);

    // Track mode: skip already-applied, warn on changed
    if (track && applied.has(file)) {
      if (applied.get(file) === hash) {
        results.push({ filename: file, status: "skipped" });
        continue;
      } else {
        results.push({ filename: file, status: "changed", message: "file changed since last apply (hash mismatch)" });
        continue;
      }
    }

    // Execute in its own transaction
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

    // Record successful application
    if (track) {
      await client.query(
        `INSERT INTO workbench.applied_migration (filename, hash, commit_hash) VALUES ($1, $2, $3)
         ON CONFLICT (filename) DO UPDATE SET hash = $2, commit_hash = $3, applied_at = now()`,
        [file, hash, commit],
      );
    }

    results.push({ filename: file, status: "applied" });
  }

  return formatResults(results, dir);
}

function formatResults(results: ApplyResult[], dir: string): string {
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

export function registerApply(s: McpServer): void {
  s.tool(
    "apply",
    "Apply SQL files from disk to the database.\n" +
      "Executes .sql files in alphabetical order, each in its own transaction.\n" +
      "With track:true (default), skips already-applied files and detects changes.\n" +
      "Use track:false for idempotent seed files that should always re-run.",
    {
      path: z.string().describe("Directory containing .sql files (relative to project root or absolute)"),
      track: z
        .boolean()
        .optional()
        .default(true)
        .describe("Track applied files to avoid re-running (default: true). Set false for seed files."),
      force: z
        .boolean()
        .optional()
        .default(false)
        .describe("Re-apply changed files instead of warning (only with track:true)"),
    },
    async ({ path: dir, track, force }) =>
      withClient(async (client) => {
        if (force && track) {
          // Force mode: clear tracked entries for changed files so they re-run
          await ensureMigrationTable(client);
          const resolved = resolveDir(dir);
          let entries: string[];
          try {
            entries = await fs.readdir(resolved);
          } catch {
            return text(`✗ directory not found: ${resolved}`);
          }
          const sqlFiles = entries.filter((f) => f.endsWith(".sql")).sort();
          for (const file of sqlFiles) {
            const filePath = path.join(resolved, file);
            const content = await fs.readFile(filePath, "utf-8");
            const hash = crypto.createHash("sha256").update(content).digest("hex").slice(0, 16);
            const { rows } = await client.query<{ hash: string }>(
              `SELECT hash FROM workbench.applied_migration WHERE filename = $1`,
              [file],
            );
            if (rows.length > 0 && rows[0].hash !== hash) {
              await client.query(`DELETE FROM workbench.applied_migration WHERE filename = $1`, [file]);
            }
          }
        }

        const result = await applyFiles(client, dir, track);
        return text(result);
      }),
  );
}
