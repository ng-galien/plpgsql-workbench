import { readdirSync } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { DEFAULT_EXCLUDE, ensureDocstoreSchema, formatSize, hashFile, mimeFromExt, walkDir } from "./utils.js";

/** Count files recursively under a directory. */
function countFiles(dirPath: string, excludeSet: Set<string>): number {
  let count = 0;
  try {
    const entries = readdirSync(dirPath, { withFileTypes: true });
    for (const entry of entries) {
      if (excludeSet.has(entry.name)) continue;
      const abs = path.join(dirPath, entry.name);
      if (entry.isDirectory()) {
        count += countFiles(abs, excludeSet);
      } else if (entry.isFile()) {
        count++;
      }
    }
  } catch {
    /* permission denied */
  }
  return count;
}

export function createScanTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "fs_scan",
      description:
        "Scan a directory and register files in docstore.file.\n" +
        "Shows subdirectories (with file counts) + files with sync status.\n" +
        "Status: new (not in DB), indexed (unchanged), modified (hash changed).\n" +
        "Supports pagination (offset/limit) and extension filter.",
      schema: z.object({
        path: z.string().describe("Root directory to scan (absolute path)"),
        recursive: z.boolean().optional().describe("Flatten all files recursively (default: true)"),
        ext: z.string().optional().describe("Filter by extension (e.g. '.pdf', '.md')"),
        limit: z.number().optional().describe("Max files to return (default: 50)"),
        offset: z.number().optional().describe("Skip first N files (default: 0)"),
        exclude: z
          .array(z.string())
          .optional()
          .describe("Directory names to exclude (default: .git, node_modules, dist, build, ...)"),
      }),
    },
    handler: async (args, _extra) => {
      const rootPath = path.resolve(args.path as string);
      const recursive = (args.recursive as boolean | undefined) ?? true;
      const extFilter = args.ext ? String(args.ext).toLowerCase() : null;
      const limit = (args.limit as number | undefined) ?? 50;
      const offset = (args.offset as number | undefined) ?? 0;
      const exclude = args.exclude as string[] | undefined;
      const excludeSet = new Set(exclude ?? DEFAULT_EXCLUDE);

      return withClient(async (client) => {
        await ensureDocstoreSchema(client);

        // Collect subdirectories (non-recursive mode only)
        const subdirs: { name: string; fileCount: number }[] = [];

        // Walk filesystem
        let allFiles: string[];
        try {
          if (recursive) {
            allFiles = await walkDir(rootPath, exclude);
          } else {
            // Shallow: list top-level entries
            allFiles = [];
            const entries = await fs.readdir(rootPath, { withFileTypes: true });
            for (const entry of entries) {
              if (excludeSet.has(entry.name)) continue;
              const abs = path.join(rootPath, entry.name);
              if (entry.isDirectory()) {
                subdirs.push({ name: entry.name, fileCount: countFiles(abs, excludeSet) });
              } else if (entry.isFile()) {
                allFiles.push(abs);
              }
            }
            subdirs.sort((a, b) => a.name.localeCompare(b.name));
          }
        } catch (err: unknown) {
          return text(
            `problem: cannot read directory: ${rootPath}\nwhere: fs_scan\nfix_hint: ${err instanceof Error ? err.message : String(err)}`,
          );
        }

        // Extension filter
        if (extFilter) {
          allFiles = allFiles.filter((f) => path.extname(f).toLowerCase() === extFilter);
        }

        // Sort by modification date descending
        const withStats = await Promise.all(
          allFiles.map(async (f) => {
            try {
              const stat = await fs.stat(f);
              return { path: f, stat, mtime: stat.mtimeMs };
            } catch {
              return null;
            }
          }),
        );
        const valid = withStats.filter((f): f is NonNullable<typeof f> => f !== null);
        valid.sort((a, b) => b.mtime - a.mtime);

        const total = valid.length;
        const page = valid.slice(offset, offset + limit);

        // Sync status: check docstore.file for each file in the page
        const pagePaths = page.map((f) => f.path);
        const { rows: dbRows } = await client.query<{ path: string; content_hash: string | null }>(
          `SELECT path, content_hash FROM docstore.file WHERE path = ANY($1)`,
          [pagePaths],
        );
        const dbMap = new Map(dbRows.map((r) => [r.path, r.content_hash]));

        // Register new/updated files in DB
        let added = 0;
        let updated = 0;
        let unchanged = 0;
        const hashCache = new Map<string, string>();

        await client.query("BEGIN");
        try {
          for (const file of page) {
            const ext = path.extname(file.path);
            const filename = path.basename(file.path);
            const mime = mimeFromExt(ext);
            const hash = await hashFile(file.path);
            hashCache.set(file.path, hash);
            const dbHash = dbMap.get(file.path);

            if (dbHash === undefined) {
              await client.query(
                `INSERT INTO docstore.file (path, filename, extension, size_bytes, content_hash, mime_type, fs_modified_at)
                 VALUES ($1, $2, $3, $4, $5, $6, $7)
                 ON CONFLICT (path) DO UPDATE SET
                   filename = $2, extension = $3, size_bytes = $4, content_hash = $5, mime_type = $6, fs_modified_at = $7`,
                [file.path, filename, ext || null, file.stat.size, hash, mime, file.stat.mtime],
              );
              added++;
            } else if (dbHash !== hash) {
              await client.query(
                `UPDATE docstore.file
                 SET filename = $2, extension = $3, size_bytes = $4, content_hash = $5, mime_type = $6, fs_modified_at = $7
                 WHERE path = $1`,
                [file.path, filename, ext || null, file.stat.size, hash, mime, file.stat.mtime],
              );
              updated++;
            } else {
              unchanged++;
            }
          }
          await client.query("COMMIT");
        } catch (err) {
          await client.query("ROLLBACK");
          throw err;
        }

        // Build output
        const parts: string[] = [];
        const sym = "✓";
        parts.push(`${sym} scan: ${rootPath}`);
        const isPartial = offset + limit < total;
        parts.push(`completeness: ${isPartial ? "partial" : "full"}`);
        parts.push(
          `total: ${total}, page: ${page.length} (offset ${offset}), added: ${added}, updated: ${updated}, unchanged: ${unchanged}`,
        );

        // Subdirectories
        if (subdirs.length > 0) {
          parts.push("");
          parts.push(`subdirs (${subdirs.length}):`);
          for (const d of subdirs) {
            parts.push(`  ${(`${d.name}/`).padEnd(40)} ${String(d.fileCount).padStart(6)} files`);
          }
        }

        // Files with status
        if (page.length > 0) {
          parts.push("");
          parts.push(`files${extFilter ? ` (${extFilter})` : ""}:`);
          for (const file of page) {
            const ext = path.extname(file.path);
            const size = formatSize(Number(file.stat.size));
            const date = file.stat.mtime.toISOString().slice(0, 10);
            const rel = path.relative(rootPath, file.path);
            const hash = hashCache.get(file.path) ?? (await hashFile(file.path));
            const dbHash = dbMap.get(file.path);
            let status = "new";
            if (dbHash !== undefined) {
              status = dbHash === hash ? "indexed" : "modified";
            }
            parts.push(`  ${rel.padEnd(45)} ${ext.padEnd(6)} ${size.padStart(8)}  ${date}  ${status}`);
          }
        }

        // Pagination + next
        parts.push("");
        parts.push("next:");
        if (offset + limit < total) {
          parts.push(`  - fs_scan path:${rootPath} offset:${offset + limit}${extFilter ? ` ext:${extFilter}` : ""}`);
        }
        if (subdirs.length > 0) {
          parts.push(`  - fs_scan path:${path.join(rootPath, subdirs[0].name)} recursive:false`);
        }
        if (page.length > 0) {
          parts.push(`  - fs_peek path:${page[0].path}`);
        }
        parts.push(`  - fs_sync path:${rootPath}`);

        return text(parts.join("\n"));
      });
    },
  };
}
