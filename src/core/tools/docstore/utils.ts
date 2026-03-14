/**
 * Shared utilities for the docstore pack.
 * Pure functions — no DI dependencies, safe to import directly.
 */

import crypto from "node:crypto";
import { createReadStream } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import type { DbClient } from "../../connection.js";

// --- Schema setup ---

let schemaReady = false;

export async function ensureDocstoreSchema(client: DbClient): Promise<void> {
  if (schemaReady) return;
  await client.query(`CREATE SCHEMA IF NOT EXISTS docstore`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS docstore.file (
      path text PRIMARY KEY,
      filename text NOT NULL,
      extension text,
      size_bytes bigint,
      content_hash text,
      mime_type text,
      fs_modified_at timestamptz,
      discovered_at timestamptz DEFAULT now(),
      metadata jsonb DEFAULT '{}'
    )
  `);
  schemaReady = true;
}

// --- File hashing ---

export function hashFile(filePath: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    const stream = createReadStream(filePath);
    stream.on("data", (data) => hash.update(data));
    stream.on("end", () => resolve(hash.digest("hex")));
    stream.on("error", reject);
  });
}

// --- Directory walking ---

export const DEFAULT_EXCLUDE = new Set([
  ".git",
  "node_modules",
  ".DS_Store",
  "__pycache__",
  ".idea",
  ".vscode",
  "dist",
  "build",
  "target",
  ".next",
]);

export async function walkDir(dir: string, exclude?: string[]): Promise<string[]> {
  const excludeSet = new Set(exclude ?? DEFAULT_EXCLUDE);
  const files: string[] = [];

  async function walk(current: string): Promise<void> {
    const entries = await fs.readdir(current, { withFileTypes: true });
    for (const entry of entries) {
      if (excludeSet.has(entry.name)) continue;
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        await walk(full);
      } else if (entry.isFile()) {
        files.push(full);
      }
    }
  }

  await walk(dir);
  return files;
}

// --- Mime type ---

const MIME_MAP: Record<string, string> = {
  ".pdf": "application/pdf",
  ".md": "text/markdown",
  ".txt": "text/plain",
  ".json": "application/json",
  ".xml": "application/xml",
  ".html": "text/html",
  ".css": "text/css",
  ".js": "application/javascript",
  ".ts": "text/typescript",
  ".sql": "application/sql",
  ".csv": "text/csv",
  ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".webp": "image/webp",
  ".zip": "application/zip",
  ".tar": "application/x-tar",
  ".gz": "application/gzip",
  ".yaml": "text/yaml",
  ".yml": "text/yaml",
  ".toml": "text/toml",
  ".sh": "application/x-sh",
  ".py": "text/x-python",
  ".java": "text/x-java",
  ".go": "text/x-go",
  ".rs": "text/x-rust",
  ".c": "text/x-c",
  ".h": "text/x-c",
  ".cpp": "text/x-c++",
};

export function mimeFromExt(ext: string): string {
  return MIME_MAP[ext.toLowerCase()] ?? "application/octet-stream";
}

// --- Formatting ---

export function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes}B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)}GB`;
}
