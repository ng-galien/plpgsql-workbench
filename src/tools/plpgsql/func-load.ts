import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import fs from "fs/promises";
import path from "path";

function resolveDir(dir: string): string {
  if (path.isAbsolute(dir)) return dir;
  return path.resolve(process.cwd(), dir);
}

interface LoadResult {
  filename: string;
  status: "loaded" | "error";
  message?: string;
}

async function loadFunctions(
  client: DbClient,
  dir: string,
): Promise<string> {
  const resolved = resolveDir(dir);

  let entries: string[];
  try {
    entries = await fs.readdir(resolved);
  } catch {
    return `problem: directory not found: ${resolved}\nwhere: pg_func_load\nfix_hint: check the path argument`;
  }

  // Collect .sql files recursively (schema/function.sql)
  const sqlFiles: { relPath: string; fullPath: string }[] = [];
  for (const entry of entries.sort()) {
    const entryPath = path.join(resolved, entry);
    const stat = await fs.stat(entryPath);
    if (stat.isDirectory()) {
      const subEntries = await fs.readdir(entryPath);
      for (const sub of subEntries.sort()) {
        if (sub.endsWith(".sql")) {
          sqlFiles.push({ relPath: `${entry}/${sub}`, fullPath: path.join(entryPath, sub) });
        }
      }
    } else if (entry.endsWith(".sql")) {
      sqlFiles.push({ relPath: entry, fullPath: entryPath });
    }
  }

  if (sqlFiles.length === 0) {
    return `no .sql files in ${resolved}`;
  }

  const results: LoadResult[] = [];

  for (const { relPath, fullPath } of sqlFiles) {
    const content = await fs.readFile(fullPath, "utf-8");
    try {
      await client.query("BEGIN");
      await client.query(content);
      await client.query("COMMIT");
      results.push({ filename: relPath, status: "loaded" });
    } catch (err: unknown) {
      await client.query("ROLLBACK").catch(() => {});
      const msg = err instanceof Error ? err.message : String(err);
      results.push({ filename: relPath, status: "error", message: msg });
    }
  }

  return formatResults(results, dir);
}

function formatResults(results: LoadResult[], dir: string): string {
  const loaded = results.filter((r) => r.status === "loaded");
  const errors = results.filter((r) => r.status === "error");

  const parts: string[] = [];

  if (errors.length > 0) {
    parts.push(`✗ ${loaded.length} loaded, ${errors.length} failed (${dir})`);
  } else {
    parts.push(`✓ ${loaded.length} function${loaded.length !== 1 ? "s" : ""} loaded (${dir})`);
  }
  parts.push(`completeness: full`);
  parts.push("");

  for (const r of results) {
    if (r.status === "loaded") {
      parts.push(`  ✓ ${r.filename}`);
    } else {
      parts.push(`  ✗ ${r.filename}`);
      parts.push(`    problem: ${r.message}`);
    }
  }

  return parts.join("\n");
}

export function createFuncLoadTool({ withClient }: {
  withClient: WithClient;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_func_load",
      description:
        "Load function SQL files from disk into the database.\n" +
        "Executes each .sql file (CREATE OR REPLACE FUNCTION) in its own transaction.\n" +
        "Idempotent: safe to re-run. Reads {path}/{schema}/{function}.sql structure.",
      schema: z.object({
        path: z.string().describe("Directory containing function .sql files (relative to project root or absolute)"),
      }),
    },
    handler: async (args, _extra) => {
      const dir = args.path as string;
      return withClient(async (client) => {
        const result = await loadFunctions(client, dir);
        return text(result);
      });
    },
  };
}
