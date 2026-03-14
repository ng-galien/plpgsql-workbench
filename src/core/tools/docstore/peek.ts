import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import { ensureDocstoreSchema, formatSize, hashFile, mimeFromExt } from "./utils.js";

const TEXT_TYPES = new Set([
  "text/plain",
  "text/markdown",
  "text/csv",
  "text/html",
  "text/css",
  "text/yaml",
  "text/toml",
  "text/typescript",
  "text/x-python",
  "text/x-java",
  "text/x-go",
  "text/x-rust",
  "text/x-c",
  "text/x-c++",
  "application/json",
  "application/xml",
  "application/javascript",
  "application/sql",
  "application/x-sh",
]);

let _hasPdftotext: boolean | null = null;
function hasPdftotext(): boolean {
  if (_hasPdftotext === null) {
    try {
      execFileSync("pdftotext", ["-v"], { stdio: "pipe" });
      _hasPdftotext = true;
    } catch {
      _hasPdftotext = false;
    }
  }
  return _hasPdftotext;
}

function extractPdfText(filePath: string, maxLines: number): string[] | null {
  if (!hasPdftotext()) return null;
  try {
    const raw = execFileSync("pdftotext", ["-layout", "-l", "3", filePath, "-"], {
      stdio: ["pipe", "pipe", "pipe"],
      maxBuffer: 1024 * 1024,
      timeout: 10000,
    });
    return raw.toString("utf-8").split("\n").slice(0, maxLines);
  } catch {
    return null;
  }
}

export function createPeekTool({ withClient }: { withClient: WithClient }): ToolHandler {
  return {
    metadata: {
      name: "fs_peek",
      description:
        "Read file content and metadata with pagination.\n" +
        "Text/code files: returns lines with offset/limit.\n" +
        "PDF files: extracts text via pdftotext (first 3 pages).\n" +
        "Binary files (images, archives): metadata only.\n" +
        "Shows sync status against docstore.file (new/indexed/modified).",
      schema: z.object({
        path: z.string().describe("Absolute file path"),
        lines: z.number().optional().describe("Max lines to return (default: 100)"),
        offset: z.number().optional().describe("Skip first N lines (default: 0)"),
      }),
    },
    handler: async (args, _extra) => {
      const filePath = path.resolve(args.path as string);
      const maxLines = (args.lines as number | undefined) ?? 100;
      const lineOffset = (args.offset as number | undefined) ?? 0;

      if (!existsSync(filePath))
        return text(`problem: file not found: ${filePath}\nwhere: fs_peek\nfix_hint: check the path argument`);

      const stat = await fs.stat(filePath);
      if (!stat.isFile())
        return text(`problem: not a file: ${filePath}\nwhere: fs_peek\nfix_hint: use fs_scan for directories`);

      const ext = path.extname(filePath);
      const mime = mimeFromExt(ext);

      // Sync status from docstore.file
      let status = "new";
      const dbInfo = await withClient(async (client) => {
        await ensureDocstoreSchema(client);
        const { rows } = await client.query<{ content_hash: string | null }>(
          `SELECT content_hash FROM docstore.file WHERE path = $1`,
          [filePath],
        );
        return rows[0] ?? null;
      });

      if (dbInfo) {
        const currentHash = await hashFile(filePath);
        status = currentHash === dbInfo.content_hash ? "indexed" : "modified";
      }

      let contentTruncated = false;

      const parts: string[] = [
        `file: ${filePath}`,
        `type: ${mime}`,
        `size: ${formatSize(Number(stat.size))}`,
        `created: ${stat.birthtime.toISOString().slice(0, 10)}`,
        `modified: ${stat.mtime.toISOString().slice(0, 10)}`,
        `status: ${status}`,
      ];

      // Content
      if (TEXT_TYPES.has(mime)) {
        try {
          const content = await fs.readFile(filePath, "utf-8");
          const allLines = content.split("\n");
          const total = allLines.length;
          const chunk = allLines.slice(lineOffset, lineOffset + maxLines);
          const hasMore = lineOffset + maxLines < total;
          if (hasMore) contentTruncated = true;

          parts.push("", `content: lines ${lineOffset + 1}-${lineOffset + chunk.length} of ${total}`);
          for (let i = 0; i < chunk.length; i++) {
            parts.push(`${String(lineOffset + i + 1).padStart(4)}| ${chunk[i]}`);
          }
          if (hasMore) {
            parts.push(`  ... (${total - lineOffset - maxLines} more lines)`);
            parts.push("", "next:");
            parts.push(`  - fs_peek path:${filePath} offset:${lineOffset + maxLines} lines:${maxLines}`);
          }
        } catch {
          parts.push("", "content: (unable to read)");
        }
      } else if (mime === "application/pdf") {
        const pdfLines = extractPdfText(filePath, lineOffset + maxLines);
        if (pdfLines) {
          const total = pdfLines.length;
          const chunk = pdfLines.slice(lineOffset, lineOffset + maxLines);
          const hasMore = lineOffset + maxLines < total;
          if (hasMore) contentTruncated = true;

          parts.push(
            "",
            `content: pdf extract (first 3 pages), lines ${lineOffset + 1}-${lineOffset + chunk.length} of ${total}`,
          );
          for (const line of chunk) {
            parts.push(`  ${line}`);
          }
          if (hasMore) {
            parts.push(`  ... (${total - lineOffset - maxLines} more lines)`);
            parts.push("", "next:");
            parts.push(`  - fs_peek path:${filePath} offset:${lineOffset + maxLines}`);
          }
        } else {
          parts.push("", "content: (pdf — pdftotext not available, metadata only)");
        }
      } else {
        parts.push("", "content: (binary file — metadata only)");
      }

      // Insert completeness after the file line
      parts.splice(1, 0, `completeness: ${contentTruncated ? "partial" : "full"}`);

      if (status === "new") {
        parts.push("", "next:");
        parts.push(`  - fs_scan path:${path.dirname(filePath)}`);
      }

      return text(parts.join("\n"));
    },
  };
}
