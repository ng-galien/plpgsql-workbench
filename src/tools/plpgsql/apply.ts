import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
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
    return `problem: directory not found: ${resolved}\nwhere: pg_apply\nfix_hint: check the path argument`;
  }

  const sqlFiles = entries.filter((f) => f.endsWith(".sql")).sort();
  if (sqlFiles.length === 0) {
    return `no .sql files in ${resolved}`;
  }

  if (track) {
    await ensureMigrationTable(client);
  }

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

    if (track && applied.has(file)) {
      if (applied.get(file) === hash) {
        results.push({ filename: file, status: "skipped" });
        continue;
      } else {
        results.push({ filename: file, status: "changed", message: "file changed since last apply (hash mismatch)" });
        continue;
      }
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

export function createApplyTool({ withClient }: {
  withClient: WithClient;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_apply",
      description:
        "Apply SQL files from disk to the database.\n" +
        "Executes .sql files in alphabetical order, each in its own transaction.\n" +
        "With track:true (default), skips already-applied files and detects changes.\n" +
        "Use track:false for idempotent seed files that should always re-run.",
      schema: z.object({
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
      }),
    },
    handler: async (args, _extra) => {
      const dir = args.path as string;
      const track = (args.track as boolean | undefined) ?? true;
      const force = (args.force as boolean | undefined) ?? false;

      return withClient(async (client) => {
        if (force && track) {
          await ensureMigrationTable(client);
          const resolved = resolveDir(dir);
          let entries: string[];
          try {
            entries = await fs.readdir(resolved);
          } catch {
            return text(`problem: directory not found: ${resolved}\nwhere: pg_apply\nfix_hint: check the path argument`);
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
      });
    },
  };
}
