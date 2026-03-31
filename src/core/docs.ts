import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

export interface Doc {
  topic: string;
  content: string;
}

function findDocsDir(): string | null {
  // tsx: runs from src/ directly
  const srcDir = join(__dirname, "docs");
  if (existsSync(srcDir)) return srcDir;
  // tsc: runs from dist/, docs are in src/
  const fallback = join(__dirname, "..", "src", "docs");
  if (existsSync(fallback)) return fallback;
  return null;
}

function parseFrontMatter(raw: string): { meta: Record<string, string>; content: string } {
  const match = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return { meta: {}, content: raw };
  const meta: Record<string, string> = {};
  for (const line of match[1]!.split("\n")) {
    const kv = line.match(/^(\w+):\s*(.+)$/);
    if (kv) meta[kv[1]!] = kv[2]!.trim();
  }
  return { meta, content: match[2]!.trim() };
}

export function loadDocs(): Doc[] {
  const dir = findDocsDir();
  if (!dir) return [];
  const files = readdirSync(dir).filter((f) => f.endsWith(".md"));
  return files.map((f) => {
    const raw = readFileSync(join(dir, f), "utf-8");
    const { meta, content } = parseFrontMatter(raw);
    const topic = meta.topic ?? f.replace(/\.md$/, "");
    return { topic, content };
  });
}
