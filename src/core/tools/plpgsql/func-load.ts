import fs from "node:fs/promises";
import path from "node:path";
import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

interface LoadResult {
  filename: string;
  status: "loaded" | "error";
  message?: string;
}

async function loadFunctions(client: DbClient, dir: string): Promise<string> {
  let entries: string[];
  try {
    entries = await fs.readdir(dir);
  } catch {
    return `problem: directory not found: ${dir}\nwhere: pg_func_load\nfix_hint: check the target schema`;
  }

  // Collect .sql files recursively (schema/function.sql)
  const sqlFiles: { relPath: string; fullPath: string }[] = [];
  for (const entry of entries.sort()) {
    const entryPath = path.join(dir, entry);
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
    return `no .sql files in ${dir}`;
  }

  const results: LoadResult[] = [];

  for (const { relPath, fullPath } of sqlFiles) {
    const content = await fs.readFile(fullPath, "utf-8");
    try {
      await client.query("BEGIN");
      await client.query(content);
      await client.query("COMMIT");
      await client.query("NOTIFY pgrst, 'reload schema'").catch(() => {});
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
    parts.push(`${loaded.length} loaded, ${errors.length} failed (${dir})`);
  } else {
    parts.push(`${loaded.length} function${loaded.length !== 1 ? "s" : ""} loaded (${dir})`);
  }
  parts.push(`completeness: full`);
  parts.push("");

  for (const r of results) {
    if (r.status === "loaded") {
      parts.push(`  ok ${r.filename}`);
    } else {
      parts.push(`  FAIL ${r.filename}`);
      parts.push(`    problem: ${r.message}`);
    }
  }

  return parts.join("\n");
}

export function createFuncLoadTool({
  withClient,
  moduleRegistry,
}: {
  withClient: WithClient;
  moduleRegistry: Promise<import("../../pgm/registry.js").ModuleRegistry>;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_func_load",
      description:
        "Load function SQL files from module src/ into the database.\n" +
        "Executes each .sql file (CREATE OR REPLACE FUNCTION) in its own transaction.\n" +
        "Path is auto-resolved from module registry (schema → module → src/).",
      schema: z.object({
        target: z.string().describe("plpgsql:// URI scope. plpgsql://schema to load all functions from src/schema/"),
      }),
    },
    handler: async (args, _extra) => {
      const target = args.target as string;
      const schemaMatch = target.match(/^plpgsql:\/\/(\w+)\/?$/);
      if (!schemaMatch) {
        return text(`problem: invalid target: ${target}\nwhere: pg_func_load\nfix_hint: expected plpgsql://schema`);
      }

      const schema = schemaMatch[1]!;
      const registry = await moduleRegistry;
      const srcDir = registry.savePath(schema);
      if (!srcDir) {
        return text(
          `problem: no module owns schema "${schema}"\n` +
            `where: pg_func_load\n` +
            `fix_hint: check modules/*/module.json schemas field`,
        );
      }

      return withClient(async (client) => {
        const result = await loadFunctions(client, srcDir);
        return text(result);
      });
    },
  };
}
