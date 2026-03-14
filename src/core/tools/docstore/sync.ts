import path from "node:path";
import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { ensureDocstoreSchema, hashFile, walkDir } from "./utils.js";

export function createSyncTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "fs_sync",
      description:
        "Compare docstore.file entries against the filesystem.\n" +
        "Reports new files (on disk, not in DB), modified (hash changed),\n" +
        "and orphaned (in DB, not on disk). Read-only — does not modify the database.\n" +
        "Use fs_scan to apply changes after reviewing the sync report.",
      schema: z.object({
        path: z.string().describe("Root directory to compare (absolute path)"),
        exclude: z
          .array(z.string())
          .optional()
          .describe("Directory names to exclude (default: .git, node_modules, dist, build, ...)"),
      }),
    },
    handler: async (args, _extra) => {
      const rootPath = path.resolve(args.path as string);
      const exclude = args.exclude as string[] | undefined;

      return withClient(async (client) => {
        await ensureDocstoreSchema(client);

        // Walk filesystem
        let diskFiles: string[];
        try {
          diskFiles = await walkDir(rootPath, exclude);
        } catch (err: unknown) {
          return text(
            `problem: cannot read directory: ${rootPath}\nwhere: fs_sync\nfix_hint: ${err instanceof Error ? err.message : String(err)}`,
          );
        }

        const diskSet = new Set(diskFiles);

        // Load DB entries under this root
        const { rows: dbRows } = await client.query<{ path: string; content_hash: string | null; size_bytes: string }>(
          `SELECT path, content_hash, size_bytes FROM docstore.file WHERE path LIKE $1`,
          [`${rootPath}/%`],
        );

        const dbMap = new Map<string, { hash: string | null; size: number }>();
        for (const r of dbRows) {
          dbMap.set(r.path, { hash: r.content_hash, size: parseInt(r.size_bytes, 10) });
        }

        // Compare
        const newFiles: string[] = [];
        const modified: string[] = [];
        const orphaned: string[] = [];
        let unchanged = 0;
        let _hashErrors = 0;

        // Files on disk
        for (const filePath of diskFiles) {
          const dbEntry = dbMap.get(filePath);
          if (!dbEntry) {
            newFiles.push(filePath);
          } else {
            try {
              const currentHash = await hashFile(filePath);
              if (currentHash !== dbEntry.hash) {
                modified.push(filePath);
              } else {
                unchanged++;
              }
            } catch {
              _hashErrors++;
            }
          }
        }

        // Files in DB but not on disk
        for (const dbPath of dbMap.keys()) {
          if (!diskSet.has(dbPath)) {
            orphaned.push(dbPath);
          }
        }

        // Format output
        const parts: string[] = [];
        const total = diskFiles.length + orphaned.length;
        const hasChanges = newFiles.length > 0 || modified.length > 0 || orphaned.length > 0;
        const sym = hasChanges ? "⚠" : "✓";

        parts.push(`${sym} sync: ${rootPath}`);
        const anyTruncated = newFiles.length > 20 || modified.length > 20 || orphaned.length > 20;
        parts.push(`completeness: ${anyTruncated ? "partial" : "full"}`);
        parts.push(
          `total: ${total}, new: ${newFiles.length}, modified: ${modified.length}, orphaned: ${orphaned.length}, unchanged: ${unchanged}`,
        );

        if (newFiles.length > 0) {
          parts.push("");
          parts.push(`new (${newFiles.length}):`);
          for (const f of newFiles.slice(0, 20)) {
            parts.push(`  + ${path.relative(rootPath, f)}`);
          }
          if (newFiles.length > 20) parts.push(`  ... and ${newFiles.length - 20} more`);
        }

        if (modified.length > 0) {
          parts.push("");
          parts.push(`modified (${modified.length}):`);
          for (const f of modified.slice(0, 20)) {
            parts.push(`  ~ ${path.relative(rootPath, f)}`);
          }
          if (modified.length > 20) parts.push(`  ... and ${modified.length - 20} more`);
        }

        if (orphaned.length > 0) {
          parts.push("");
          parts.push(`orphaned (${orphaned.length}):`);
          for (const f of orphaned.slice(0, 20)) {
            parts.push(`  - ${path.relative(rootPath, f)}`);
          }
          if (orphaned.length > 20) parts.push(`  ... and ${orphaned.length - 20} more`);
        }

        if (hasChanges) {
          parts.push("");
          parts.push("next:");
          parts.push(`  - fs_scan path:${rootPath} (to register new and update modified)`);
          if (orphaned.length > 0) {
            parts.push(
              `  - query DELETE FROM docstore.file WHERE path LIKE '${rootPath}/%' AND path NOT IN (SELECT path FROM docstore.file WHERE ...)`,
            );
          }
        }

        return text(parts.join("\n"));
      });
    },
  };
}
