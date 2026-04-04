import { execFileSync } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { z } from "zod";
import type { ToolHandler, WithClient } from "../../core/container.js";
import { text } from "../../core/helpers.js";
import type { ModuleInfo, ModuleRegistry } from "../../core/pgm/registry.js";

export function createHealthTool({
  withClient,
  moduleRegistry,
}: {
  withClient: WithClient;
  moduleRegistry: Promise<ModuleRegistry>;
}): ToolHandler {
  return {
    metadata: {
      name: "ws_health",
      description:
        "Workspace health check — single call for the lead to assess overall state.\n" +
        "Returns: lead dashboard (inbox, sent tracking, orphan issues), pending tasks, SQL coherence (DB vs src/), git status.\n" +
        "Use during lead routine to monitor agents and workspace.",
      schema: z.object({
        module: z.string().optional().describe("Filter by module name (default: all)"),
      }),
    },
    handler: async (args) => {
      const filterMod = args.module as string | undefined;
      const registry = await moduleRegistry;
      const modules: ModuleInfo[] = registry.allModules();
      const filtered = filterMod ? modules.filter((m: ModuleInfo) => m.name === filterMod) : modules;

      if (filtered.length === 0) {
        return text(`no module found${filterMod ? ` matching "${filterMod}"` : ""}`);
      }

      return withClient(async (client) => {
        const parts: string[] = [];

        // ── 1. Lead dashboard ──
        parts.push("== LEAD ==");

        // Inbox: pending messages for lead
        const { rows: inbox } = await client.query<{
          id: number;
          from_module: string;
          msg_type: string;
          subject: string;
          status: string;
          priority: string;
          created_at: Date;
        }>(
          `SELECT id, from_module, msg_type, subject, status, priority, created_at
             FROM workbench.agent_message
            WHERE to_module = 'lead' AND status IN ('new', 'acknowledged')
            ORDER BY CASE WHEN status = 'new' THEN 0 ELSE 1 END, created_at DESC`,
        );
        if (inbox.length > 0) {
          parts.push(`  inbox: ${inbox.length} pending`);
          for (const m of inbox) {
            const pri = m.priority === "high" ? " HIGH" : "";
            parts.push(`    #${m.id} [${m.status}${pri}] from:${m.from_module} ${m.subject}`);
          }
        } else {
          parts.push("  inbox: empty");
        }

        // Sent: unresolved messages from lead with age
        const { rows: sent } = await client.query<{
          id: number;
          to_module: string;
          subject: string;
          status: string;
          priority: string;
          created_at: Date;
          age_min: number;
        }>(
          `SELECT id, to_module, subject, status, priority, created_at,
                  EXTRACT(EPOCH FROM now() - created_at)::int / 60 AS age_min
             FROM workbench.agent_message
            WHERE from_module = 'lead' AND status IN ('new', 'acknowledged')
            ORDER BY created_at ASC`,
        );
        if (sent.length > 0) {
          parts.push(`  sent unresolved: ${sent.length}`);
          for (const m of sent) {
            const pri = m.priority === "high" ? " HIGH" : "";
            const stale = m.age_min >= 15 ? " STALE" : "";
            parts.push(`    #${m.id} [${m.status}${pri}${stale}] -> ${m.to_module}: ${m.subject} (${m.age_min}min)`);
          }
        } else {
          parts.push("  sent: all resolved");
        }

        // Orphan issues: no message dispatched
        const { rows: orphans } = await client.query<{
          id: number;
          issue_type: string;
          module: string;
          description: string;
        }>(
          `SELECT id, issue_type, module, description
             FROM workbench.issue_report
            WHERE status = 'open' AND message_id IS NULL`,
        );
        if (orphans.length > 0) {
          parts.push(`  orphan issues: ${orphans.length}`);
          for (const o of orphans) {
            parts.push(`    #${o.id} [${o.issue_type}] ${o.module}: ${o.description.slice(0, 80)}`);
          }
        } else {
          parts.push("  orphan issues: none");
        }

        // ── 2. Pending tasks ──
        parts.push("");
        const { rows: tasks } = await client.query<{
          id: number;
          from_module: string;
          to_module: string;
          msg_type: string;
          subject: string;
          status: string;
          priority: string;
        }>(
          `SELECT id, from_module, to_module, msg_type, subject, status, priority
             FROM workbench.agent_message
            WHERE msg_type = 'task'
              AND ($1::text IS NULL OR to_module = $1)
            ORDER BY
              CASE WHEN status = 'new' THEN 0 WHEN status = 'acknowledged' THEN 1 ELSE 2 END,
              created_at DESC`,
          [filterMod ?? null],
        );

        parts.push("== TASKS ==");
        const pending = tasks.filter((t) => t.status !== "resolved");
        const resolved = tasks.filter((t) => t.status === "resolved");
        if (pending.length === 0 && resolved.length === 0) {
          parts.push("  (no tasks)");
        } else {
          if (pending.length > 0) {
            parts.push(`  pending: ${pending.length}`);
            for (const t of pending) {
              const pri = t.priority === "high" ? " HIGH" : "";
              parts.push(`    #${t.id} [${t.status}${pri}] ${t.from_module} -> ${t.to_module}: ${t.subject}`);
            }
          }
          if (resolved.length > 0) {
            parts.push(`  resolved: ${resolved.length}`);
            for (const t of resolved.slice(0, 10)) {
              parts.push(`    #${t.id} [ok] ${t.from_module} -> ${t.to_module}: ${t.subject}`);
            }
            if (resolved.length > 10) parts.push(`    ... +${resolved.length - 10} more`);
          }
        }

        // ── 3. SQL coherence per module ──
        parts.push("");
        parts.push("== COHERENCE (DB vs src/) ==");

        for (const mod of filtered) {
          const schemas = [mod.schemas.public, mod.schemas.test, mod.schemas.qa].filter((s): s is string => !!s);
          if (schemas.length === 0) continue;

          // Get DB functions for these schemas
          const { rows: dbFuncs } = await client.query<{ schema: string; name: string }>(
            `SELECT n.nspname AS schema, p.proname AS name
               FROM pg_proc p
               JOIN pg_namespace n ON n.oid = p.pronamespace
               JOIN pg_language l ON l.oid = p.prolang
              WHERE n.nspname = ANY($1) AND l.lanname IN ('sql','plpgsql')
                AND NOT EXISTS (
                  SELECT 1 FROM pg_depend d JOIN pg_extension e ON e.oid = d.refobjid
                  WHERE d.objid = p.oid AND d.deptype = 'e')`,
            [schemas],
          );

          // Check src/ files
          const modPath = mod.path;
          const srcDir = path.join(modPath, "src");
          const qaDir = path.join(modPath, "qa");
          const missing: string[] = [];
          const extra: string[] = [];

          const dbBySchema = new Map<string, Set<string>>();
          for (const f of dbFuncs) {
            if (!dbBySchema.has(f.schema)) dbBySchema.set(f.schema, new Set());
            dbBySchema.get(f.schema)!.add(f.name);
          }

          // Check DB funcs have src/ files
          for (const [schema, names] of dbBySchema) {
            const baseDir = schema.endsWith("_qa") ? qaDir : srcDir;
            for (const name of names) {
              const srcFile = path.join(baseDir, schema, `${name}.sql`);
              try {
                await fs.access(srcFile);
              } catch {
                missing.push(`${schema}/${name}.sql`);
              }
            }
          }

          // Check for extra files in src/ not in DB
          for (const schema of schemas) {
            const baseDir = schema.endsWith("_qa") ? qaDir : srcDir;
            const schemaDir = path.join(baseDir, schema);
            try {
              const files = await fs.readdir(schemaDir);
              const dbNames = dbBySchema.get(schema) ?? new Set();
              for (const f of files) {
                if (!f.endsWith(".sql")) continue;
                const funcName = f.replace(/(_\d+)?\.sql$/, "");
                if (!dbNames.has(funcName)) extra.push(`${schema}/${f}`);
              }
            } catch {
              /* dir doesn't exist */
            }
          }

          const totalFuncs = dbFuncs.length;
          if (missing.length === 0 && extra.length === 0) {
            parts.push(`  ${mod.name}: ok (${totalFuncs} functions, ${schemas.join(",")})`);
          } else {
            parts.push(`  ${mod.name}: MISMATCH (${totalFuncs} functions)`);
            for (const m of missing) parts.push(`    missing src: ${m}`);
            for (const e of extra) parts.push(`    extra src: ${e}`);
          }
        }

        // ── 4. Git status per module ──
        parts.push("");
        parts.push("== GIT STATUS ==");

        try {
          const gitOut = execFileSync("git", ["status", "--porcelain", "--", "modules/"], {
            encoding: "utf8",
            cwd: registry.workspaceRoot,
            stdio: ["ignore", "pipe", "pipe"],
          });

          if (!gitOut.trim()) {
            parts.push("  clean (no uncommitted changes)");
          } else {
            // Group by module
            const byMod = new Map<string, string[]>();
            for (const line of gitOut.trim().split("\n")) {
              const file = line.slice(3); // skip status chars
              const match = file.match(/^modules\/([^/]+)\//);
              if (match) {
                const modName = match[1]!;
                if (filterMod && modName !== filterMod) continue;
                if (!byMod.has(modName)) byMod.set(modName, []);
                byMod.get(modName)!.push(line.trim());
              }
            }

            for (const [modName, files] of [...byMod.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
              parts.push(`  ${modName}: ${files.length} file(s) changed`);
              for (const f of files.slice(0, 8)) parts.push(`    ${f}`);
              if (files.length > 8) parts.push(`    ... +${files.length - 8} more`);
            }

            // Also check root files
            const rootGit = execFileSync(
              "git",
              ["status", "--porcelain", "--", "src/", "seed/", "Makefile", "package.json", "docker-compose.yml"],
              { encoding: "utf8", cwd: registry.workspaceRoot, stdio: ["ignore", "pipe", "pipe"] },
            );
            if (rootGit.trim()) {
              const rootFiles = rootGit.trim().split("\n");
              parts.push(`  (root): ${rootFiles.length} file(s) changed`);
              for (const f of rootFiles.slice(0, 5)) parts.push(`    ${f.trim()}`);
              if (rootFiles.length > 5) parts.push(`    ... +${rootFiles.length - 5} more`);
            }
          }
        } catch {
          parts.push("  (git not available)");
        }

        return text(parts.join("\n"));
      });
    },
  };
}
