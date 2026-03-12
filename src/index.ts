#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import express from "express";
import fsSync from "fs";
import fs from "fs/promises";
import http from "http";
import os from "os";
import path from "path";
import pino from "pino";
import { WebSocketServer, WebSocket } from "ws";
import pty from "node-pty";
import { execFileSync, execFile, spawn as cpSpawn, type ChildProcess } from "child_process";
import { buildContainer, mountTools, type ToolPack } from "./container.js";
import { plpgsqlPack } from "./packs/plpgsql.js";
import { docstorePack } from "./packs/docstore.js";
import { googlePack } from "./packs/google.js";
import { docmanPack } from "./packs/docman.js";

const log = pino({
  level: process.env.LOG_LEVEL ?? "info",
  transport: { target: "pino-pretty", options: { colorize: true } },
});

// --- Config loading ---
// WORKBENCH_CONFIG=apps/docman/workbench.json → load app-specific config
// Without it → load all packs (dev mode)

interface WorkbenchConfig {
  name: string;
  packs: string[];
  connection?: string;
  port?: number;
}

const ALL_PACKS: Record<string, ToolPack> = {
  plpgsql: plpgsqlPack,
  docstore: docstorePack,
  google: googlePack,
  docman: docmanPack,
};

function loadConfig(): WorkbenchConfig {
  const configPath = process.env.WORKBENCH_CONFIG;
  if (configPath) {
    const resolved = path.resolve(configPath);
    const raw = JSON.parse(fsSync.readFileSync(resolved, "utf-8"));
    log.info({ config: resolved, app: raw.name, packs: raw.packs }, "Loaded app config");
    return raw;
  }
  // Default: all packs
  return {
    name: "dev",
    packs: Object.keys(ALL_PACKS),
  };
}

const appConfig = loadConfig();

// Apply connection from config (config > env > default)
if (appConfig.connection) {
  process.env.PLPGSQL_CONNECTION = appConfig.connection;
}

const packConfigs: Record<string, Record<string, unknown>> = {};
const packImpls: Record<string, ToolPack> = {};
for (const name of appConfig.packs) {
  if (!ALL_PACKS[name]) {
    log.warn({ pack: name }, "Unknown pack in config, skipping");
    continue;
  }
  packConfigs[name] = {};
  packImpls[name] = ALL_PACKS[name];
}

log.info({ app: appConfig.name, packs: Object.keys(packImpls) }, "Building container");

const container = buildContainer(
  { packs: packConfigs },
  packImpls,
);

const registry: Map<string, unknown> = container.resolve("toolRegistry");
log.info({ tools: [...registry.keys()], count: registry.size }, "Tools registered");

async function createServer(): Promise<McpServer> {
  const s = new McpServer({ name: "plpgsql-workbench", version: "0.1.0" });
  await mountTools(s, container);
  return s;
}

const PORT = appConfig.port ?? parseInt(process.env.MCP_PORT ?? "3100", 10);

const app = express();
app.use(express.json());

app.post("/mcp", async (req, res) => {
  log.debug({ method: req.body?.method }, "MCP request");
  const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
  const server = await createServer();
  let closed = false;

  const closeAll = async () => {
    if (closed) return;
    closed = true;
    await transport.close().catch(() => {});
    await server.close().catch(() => {});
  };

  res.on("close", () => { void closeAll(); });

  try {
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
  } catch (err) {
    log.error(err, "Error handling MCP request");
    if (!res.headersSent) {
      res.status(500).json({
        jsonrpc: "2.0",
        error: {
          code: -32603,
          message: "Internal server error",
        },
        id: null,
      });
    } else if (!res.writableEnded) {
      res.end();
    }
  } finally {
    await closeAll();
  }
});

// --- Claude Code workflow guard ---
// Workflow strict:
//   DDL (schemas, tables, indexes) → fichiers SQL + pg_schema
//   Fonctions PL/pgSQL → pg_func_set + pg_test, puis pg_func_save quand stable
//   pg_query → SELECT ad-hoc et DML données uniquement
const WORKFLOW = [
  "Workflow strict:",
  "  1. DDL (schemas, tables, indexes) -> fichiers SQL sur disque + pg_schema",
  "  2. Fonctions PL/pgSQL -> pg_func_set pour creer/iterer + pg_test pour valider",
  "  3. Quand stable -> pg_func_save pour exporter en fichiers .sql",
  "  4. pg_query -> SELECT ad-hoc et DML donnees uniquement",
].join("\n");

const DDL_PATTERN = /\b(CREATE\s+(SCHEMA|TABLE|INDEX|EXTENSION|TYPE)|ALTER\s+(TABLE|SCHEMA|TYPE)|DROP\s+(SCHEMA|TABLE|INDEX|TYPE|EXTENSION))\b/i;
const FUNC_PATTERN = /\bCREATE\s+(OR\s+REPLACE\s+)?FUNCTION\b/i;
const DESTRUCTIVE_PATTERN = /\b(DROP\s+FUNCTION|TRUNCATE|GRANT\s+|REVOKE\s+)\b/i;
// Note: DROP FUNCTION stays blocked in pg_query — agents must use pg_func_del instead
// Detect cross-module calls to _prefix internal functions in SQL body
const INTERNAL_CALL_RE = /\b(\w+)\._(\w+)\s*\(/g;

// moduleRegistry is registered as a Promise — await it once at startup
let moduleRegistry: import("./pgm/registry.js").ModuleRegistry | null = null;
const moduleRegistryPromise: Promise<import("./pgm/registry.js").ModuleRegistry> = container.resolve("moduleRegistry");
moduleRegistryPromise.then((r) => { moduleRegistry = r; }).catch(() => {});

function logHook(mod: string, tool: string, action: string, allowed: boolean, reason?: string) {
  try {
    const pool: import("pg").Pool = container.resolve("pool");
    pool.query(`SELECT workbench.log_hook($1,$2,$3,$4,$5)`,
      [mod, tool, action, allowed, reason ?? null],
    ).catch(() => {});
  } catch { /* pool not ready */ }
}

function deny(res: import("express").Response, reason: string, mod?: string, tool?: string, action?: string) {
  if (mod && tool) logHook(mod, tool, action ?? "", false, reason);
  res.json({ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: reason } });
}
function allow(res: import("express").Response, mod?: string, tool?: string, action?: string) {
  if (mod && tool) logHook(mod, tool, action ?? "", true);
  res.json({ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "allow" } });
}

// Validate module name on all hook endpoints — one agent = one module, no comma lists
function validateModuleName(req: import("express").Request, res: import("express").Response, next: import("express").NextFunction) {
  const mod = req.params.module as string;
  if (!mod || mod.includes(",")) {
    return res.status(400).json({
      error: `Invalid module name "${mod}". Each agent must have a single unique module name — no comma-separated lists.`,
    });
  }
  next();
}
app.post("/hooks/:module", validateModuleName);
app.post("/hooks/:module/session", validateModuleName);
app.post("/hooks/:module/stop", validateModuleName);

app.post("/hooks/:module", (req, res) => {
  const mod = req.params.module;
  const { tool_name, tool_input } = req.body ?? {};
  // Lead agent (orchestrator) bypasses all restrictions
  if (mod === "lead") return allow(res, mod, tool_name);
  if (!moduleRegistry) {
    // Registry not loaded yet — allow (fail-open during startup)
    return allow(res, mod, tool_name, "startup");
  }
  const mapping = moduleRegistry.resolveByName(mod) ?? moduleRegistry.resolve([mod]) ?? moduleRegistry.resolve([`${mod}_ut`]);
  const schemas = mapping?.schemas ?? [mod];

  // Rule: pg_query must not do DDL, function management, or destructive ops
  if (tool_name === "mcp__plpgsql-workbench__pg_query") {
    const sql = (tool_input?.sql ?? "") as string;
    if (FUNC_PATTERN.test(sql)) {
      log.warn({ mod, sql: sql.slice(0, 80) }, "hook: blocked CREATE FUNCTION in pg_query");
      return deny(res, "pg_query interdit pour les fonctions. Utilise pg_func_set + pg_test.\n\n" + WORKFLOW, mod, tool_name, sql.slice(0, 120));
    }
    if (DDL_PATTERN.test(sql)) {
      log.warn({ mod, sql: sql.slice(0, 80) }, "hook: blocked DDL in pg_query");
      return deny(res, "pg_query interdit pour le DDL. Ecris un fichier SQL + pg_schema.\n\n" + WORKFLOW, mod, tool_name, sql.slice(0, 120));
    }
    if (DESTRUCTIVE_PATTERN.test(sql)) {
      log.warn({ mod, sql: sql.slice(0, 80) }, "hook: blocked destructive op in pg_query");
      return deny(res, "pg_query interdit pour DROP FUNCTION / TRUNCATE / GRANT / REVOKE. Utilise pg_func_del pour supprimer une fonction.\n\n" + WORKFLOW, mod, tool_name, sql.slice(0, 120));
    }
  }

  // Rule: Write/Edit must stay within module directory and respect workflow
  if (tool_name === "Write" || tool_name === "Edit") {
    const filePath = path.resolve((tool_input?.file_path ?? "") as string);
    const content = (tool_input?.content ?? tool_input?.new_string ?? "") as string;
    const modulePath = mapping?.modulePath;
    if (mod !== "lead" && modulePath && !filePath.startsWith(path.resolve(modulePath))) {
      log.warn({ mod, file: filePath, allowed: modulePath }, "hook: blocked file op outside module");
      return deny(res, `Module ${mod}: ${tool_name} interdit hors du repertoire du module (${modulePath}). Travaille uniquement dans le repertoire du module.`, mod, tool_name, filePath);
    }
    if (filePath.endsWith(".func.sql")) {
      log.warn({ mod, file: filePath }, "hook: blocked direct write to .func.sql");
      return deny(res, "*.func.sql est genere par pg_pack. Utilise pg_func_set pour iterer, puis pg_pack pour exporter.\n\n" + WORKFLOW, mod, tool_name, filePath);
    }
    if (tool_name === "Write" && filePath.endsWith(".sql") && FUNC_PATTERN.test(content)) {
      log.warn({ mod, file: filePath }, "hook: blocked Write of SQL function file");
      return deny(res, "Interdit d'ecrire des fonctions dans des fichiers SQL. Utilise pg_func_set + pg_test, puis pg_func_save quand stable.\n\n" + WORKFLOW, mod, tool_name, filePath);
    }
  }

  // Rule: pg_func_set must target a schema owned by this module
  if (tool_name === "mcp__plpgsql-workbench__pg_func_set") {
    const schema = (tool_input?.schema ?? "") as string;
    if (schema && !schemas.includes(schema)) {
      log.warn({ mod, schema, allowed: schemas }, "hook: blocked cross-module pg_func_set");
      return deny(res, `Module ${mod}: pg_func_set interdit sur le schema '${schema}'. Schemas autorises: ${schemas.join(", ")}`, mod, tool_name, schema);
    }
    // Check function body for cross-module _internal() calls
    const body = (tool_input?.body ?? "") as string;
    const internalCalls: string[] = [];
    let match: RegExpExecArray | null;
    const re = new RegExp(INTERNAL_CALL_RE.source, INTERNAL_CALL_RE.flags);
    while ((match = re.exec(body)) !== null) {
      const callSchema = match[1];
      if (!schemas.includes(callSchema)) {
        internalCalls.push(`${callSchema}._${match[2]}`);
      }
    }
    if (internalCalls.length > 0) {
      log.warn({ mod, calls: internalCalls }, "hook: blocked cross-module _internal calls");
      return deny(res, `Module ${mod}: appel a des fonctions internes d'un autre module interdit.\nViolations: ${internalCalls.join(", ")}\n\nConvention: schema._name() = interne, cross-module interdit.`, mod, tool_name, internalCalls.join(","));
    }
    // pgv-specific: no inline styles
    if (schema === "pgv" && /style\s*=\s*"/.test(body)) {
      log.warn({ mod }, "hook: blocked inline style in pgv function");
      return deny(res, "Les fonctions pgv ne doivent pas contenir de style inline (style=\"...\"). Utilise class=\"pgv-*\" et definis les styles dans pgview.css.", mod, tool_name, "inline-style");
    }
  }

  // Rule: pg_func_edit must target a schema owned by this module
  if (tool_name === "mcp__plpgsql-workbench__pg_func_edit") {
    const schema = (tool_input?.schema ?? "") as string;
    if (schema && !schemas.includes(schema)) {
      log.warn({ mod, schema, allowed: schemas }, "hook: blocked cross-module pg_func_edit");
      return deny(res, `Module ${mod}: pg_func_edit interdit sur le schema '${schema}'. Schemas autorises: ${schemas.join(", ")}`, mod, tool_name, schema);
    }
  }

  // Rule: pg_func_del must target a schema owned by this module
  if (tool_name === "mcp__plpgsql-workbench__pg_func_del") {
    const uri = (tool_input?.uri ?? "") as string;
    const match = uri.match(/^plpgsql:\/\/([^/]+)/);
    const schema = match?.[1] ?? "";
    if (schema && !schemas.includes(schema)) {
      log.warn({ mod, schema, allowed: schemas }, "hook: blocked cross-module pg_func_del");
      return deny(res, `Module ${mod}: pg_func_del interdit sur le schema '${schema}'. Schemas autorises: ${schemas.join(", ")}`, mod, tool_name, schema);
    }
  }

  allow(res, mod, tool_name);
});

// --- SessionStart hook — inject inbox on agent startup ---
app.post("/hooks/:module/session", async (req, res) => {
  const mod = req.params.module;
  try {
    const pool: import("pg").Pool = container.resolve("pool");
    const { rows } = await pool.query(
      `SELECT * FROM workbench.inbox_pending($1)`, [mod],
    );
    if (rows.length > 0) {
      const lines = rows.map((r: any) =>
        `  #${r.id} [${r.msg_type}] from ${r.from_module}: ${r.subject}`
      );
      return res.json({
        hookSpecificOutput: {
          hookEventName: "SessionStart",
          additionalContext:
            `[INBOX] You have ${rows.length} pending message(s). ` +
            `Use pg_msg_inbox module:${mod} to read details and resolve.\n` +
            lines.join("\n"),
        },
      });
    }
  } catch {
    // Table might not exist yet — silent
  }
  res.json({ hookSpecificOutput: { hookEventName: "SessionStart" } });
});

// --- Stop hook — block if pending messages, let pass otherwise ---
app.post("/hooks/:module/stop", async (req, res) => {
  const mod = req.params.module;
  // Prevent infinite loops: if already continuing from a previous stop hook block, allow stop
  if (req.body?.stop_hook_active) {
    return res.json({});
  }
  try {
    const pool: import("pg").Pool = container.resolve("pool");
    const inbox = await pool.query(`SELECT * FROM workbench.inbox_new($1)`, [mod]);
    const resolved = await pool.query(`SELECT * FROM workbench.ack_resolved($1)`, [mod]);

    const parts: string[] = [];

    if (inbox.rows.length > 0) {
      parts.push(`[INBOX] ${inbox.rows.length} new message(s):`);
      for (const r of inbox.rows) {
        parts.push(`  #${r.id} [${r.msg_type}] from ${r.from_module}: ${r.subject}`);
      }
      parts.push(`→ Use pg_msg_inbox module:${mod} to read, then resolve each message before stopping.`);
    }

    if (resolved.rows.length > 0) {
      parts.push(`[RESOLVED] ${resolved.rows.length} of your message(s) were resolved:`);
      for (const r of resolved.rows) {
        parts.push(`  #${r.id} -> ${r.to_module}: ${r.subject}${r.resolution ? ` — ${r.resolution}` : ""}`);
      }
      parts.push(`→ Use pg_msg_inbox module:${mod} to acknowledge these resolutions before stopping.`);
    }

    if (parts.length > 0) {
      return res.json({ decision: "block", reason: parts.join("\n") });
    }
  } catch {
    // Table might not exist yet — silent
  }
  res.json({});
});

// --- Filesystem browse API (for folder picker) ---
function esc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

app.get("/api/browse", async (req, res) => {
  // Only available in dev mode — blocks unauthenticated filesystem access in production
  if (process.env.WORKBENCH_MODE !== "dev") {
    return res.status(403).send("Forbidden: /api/browse only available in WORKBENCH_MODE=dev");
  }
  let dir = (req.query.path as string) || os.homedir();
  // Walk up to a valid directory if the path doesn't exist
  let resolved = path.resolve(dir);
  for (let i = 0; i < 20; i++) {
    try { await fs.access(resolved); break; } catch { resolved = path.dirname(resolved); }
  }
  try {
    const parent = path.dirname(resolved);
    const entries = await fs.readdir(resolved, { withFileTypes: true });
    const dirs = entries
      .filter((e) => e.isDirectory() && !e.name.startsWith("."))
      .map((e) => e.name)
      .sort();

    const lines: string[] = [];
    lines.push(`<div class="folder-path" id="folder-current-path">${esc(resolved)}</div>`);
    lines.push(`<div class="folder-list">`);
    if (resolved !== parent) {
      lines.push(`<a href="#" data-path="${esc(parent)}" class="folder-up"><span class="folder-icon">&#x2B06;</span> ..</a>`);
    }
    for (const d of dirs) {
      const full = path.join(resolved, d);
      lines.push(
        `<a href="#" data-path="${esc(full)}">` +
        `<span class="folder-icon">&#x1F4C1;</span> ${esc(d)}</a>`
      );
    }
    if (dirs.length === 0) lines.push(`<div class="folder-empty">Aucun sous-dossier</div>`);
    lines.push(`</div>`);

    res.type("html").send(lines.join("\n"));
  } catch {
    res.type("html").status(400).send(`<p>Impossible de lire : <code>${esc(dir)}</code></p>`);
  }
});

// --- Static assets for preview (pgview.css, module CSS/JS) ---
if (process.env.WORKBENCH_MODE === "dev") {
  const wsRoot = (() => {
    let dir = process.cwd();
    for (let i = 0; i < 10; i++) {
      if (fsSync.existsSync(path.join(dir, "modules"))) return dir;
      dir = path.dirname(dir);
    }
    return process.cwd();
  })();
  // Serve synced assets from dev/frontend/ (make dev-sync output)
  const devFrontend = path.join(wsRoot, "dev", "frontend");
  if (fsSync.existsSync(devFrontend)) {
    app.use(express.static(devFrontend));
  }
  // Fallback: serve from each module's frontend/ directly
  const modulesDir = path.join(wsRoot, "modules");
  if (fsSync.existsSync(modulesDir)) {
    for (const entry of fsSync.readdirSync(modulesDir, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        const modFrontend = path.join(modulesDir, entry.name, "frontend");
        if (fsSync.existsSync(modFrontend)) {
          app.use(express.static(modFrontend));
        }
      }
    }
  }
}

// --- Preview endpoint — render SQL output in pgView shell ---
app.get("/preview", async (req, res) => {
  if (process.env.WORKBENCH_MODE !== "dev") {
    return res.status(403).send("Forbidden: /preview only available in WORKBENCH_MODE=dev");
  }
  const sql = (req.query.sql as string) || "";
  if (!sql) {
    return res.status(400).send("Missing ?sql= parameter");
  }
  const pool: import("pg").Pool = container.resolve("pool");
  try {
    const { rows } = await pool.query(`SELECT (${sql})::text AS html`);
    const html = rows[0]?.html ?? "";
    // Wrap in minimal pgView shell
    const page = `<!DOCTYPE html>
<html lang="fr" data-theme="light">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>pg_preview</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css">
  <link rel="stylesheet" href="/pgview.css">
  <style>body { padding: 2rem; }</style>
</head>
<body>
  <main class="container">
    ${html}
  </main>
  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
  <script>
    document.querySelectorAll('md').forEach(el => {
      const div = document.createElement('div');
      div.innerHTML = marked.parse(el.textContent);
      el.replaceWith(div);
    });
  </script>
</body>
</html>`;
    res.type("html").send(page);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    res.status(500).type("html").send(`<pre style="color:red">${esc(msg)}</pre>`);
  }
});

app.get("/mcp", async (_req, res) => {
  res.writeHead(405).end("Method Not Allowed");
});

app.delete("/mcp", async (_req, res) => {
  res.writeHead(405).end("Method Not Allowed");
});

// --- WebSocket terminal server (agent terminals for ops dashboard) ---
const httpServer = http.createServer(app);
const wss = new WebSocketServer({ noServer: true });

// Active terminal sessions: module -> { pty, clients }
const terminals = new Map<string, { proc: pty.IPty; clients: Set<WebSocket>; sessionId: number | null }>();

async function createAgentSession(mod: string): Promise<number | null> {
  try {
    const pool: import("pg").Pool = container.resolve("pool");
    const { rows } = await pool.query(
      `SELECT workbench.session_create($1, $2)`, [mod, process.pid],
    );
    return rows[0]?.session_create ?? null;
  } catch { return null; }
}

async function endAgentSession(sessionId: number | null, status: string) {
  if (!sessionId) return;
  try {
    const pool: import("pg").Pool = container.resolve("pool");
    await pool.query(`SELECT workbench.session_end($1, $2)`, [sessionId, status]);
  } catch { /* silent */ }
}

function resolveWorkspaceRoot(): string {
  let dir = process.cwd();
  for (let i = 0; i < 10; i++) {
    if (fsSync.existsSync(path.join(dir, "modules"))) return dir;
    dir = path.dirname(dir);
  }
  return process.cwd();
}

function resolveModulePath(mod: string): string {
  return path.join(resolveWorkspaceRoot(), "modules", mod);
}

httpServer.on("upgrade", (req, socket, head) => {
  if (process.env.WORKBENCH_MODE !== "dev") {
    socket.destroy();
    return;
  }

  // /ws/tmux/:session — read-only attach to tmux session
  const tmuxMatch = req.url?.match(/^\/ws\/tmux\/([a-zA-Z0-9_.-]+)$/);
  if (tmuxMatch) {
    const session = tmuxMatch[1];
    wss.handleUpgrade(req, socket, head, (ws) => {
      handleTmuxAttach(ws, session);
    });
    return;
  }

  // /ws/terminal/:module — interactive agent terminal
  const match = req.url?.match(/^\/ws\/terminal\/([a-z0-9_-]+)$/);
  if (!match) {
    socket.destroy();
    return;
  }
  const mod = match[1];
  wss.handleUpgrade(req, socket, head, (ws) => {
    wss.emit("connection", ws, req, mod);
  });
});

wss.on("connection", async (ws: WebSocket, _req: http.IncomingMessage, mod: string) => {
  let term = terminals.get(mod);

  if (!term || term.proc.pid <= 0) {
    // Spawn new terminal for this module
    const modPath = resolveModulePath(mod);
    if (!fsSync.existsSync(modPath)) {
      ws.send(`\r\n\x1b[31mModule directory not found: ${modPath}\x1b[0m\r\n`);
      ws.close();
      return;
    }

    const sessionId = await createAgentSession(mod);
    const shell = process.env.SHELL ?? "/bin/zsh";
    const proc = pty.spawn(shell, [], {
      name: "xterm-256color",
      cols: 120,
      rows: 40,
      cwd: modPath,
      env: { ...process.env, TERM: "xterm-256color" } as Record<string, string>,
    });

    term = { proc, clients: new Set(), sessionId };
    terminals.set(mod, term);

    proc.onData((data: string) => {
      for (const client of term!.clients) {
        if (client.readyState === 1) client.send(data);
      }
    });

    proc.onExit(({ exitCode }) => {
      log.info({ mod, exitCode }, "Agent terminal exited");
      void endAgentSession(term!.sessionId, exitCode === 0 ? "done" : "error");
      for (const client of term!.clients) {
        client.send(`\r\n\x1b[33m[Terminal exited with code ${exitCode}]\x1b[0m\r\n`);
      }
      terminals.delete(mod);
    });

    log.info({ mod, pid: proc.pid, cwd: modPath }, "Spawned agent terminal");
  }

  term.clients.add(ws);

  ws.on("message", (data: Buffer | string) => {
    const msg = typeof data === "string" ? data : data.toString();
    // Handle resize messages
    try {
      const parsed = JSON.parse(msg);
      if (parsed.type === "resize" && parsed.cols && parsed.rows) {
        term!.proc.resize(parsed.cols, parsed.rows);
        return;
      }
    } catch { /* not JSON, treat as input */ }
    term!.proc.write(msg.toString());
  });

  ws.on("close", () => {
    term?.clients.delete(ws);
    // Don't kill terminal when last client disconnects — keep it alive
  });
});

// --- REST API for ops dashboard ---
app.get("/api/agents", async (_req, res) => {
  if (process.env.WORKBENCH_MODE !== "dev") return res.status(403).send("Forbidden");
  try {
    const pool: import("pg").Pool = container.resolve("pool");
    const { rows } = await pool.query(`SELECT * FROM workbench.api_sessions()`);
    for (const row of rows) {
      row.has_terminal = terminals.has(row.module);
    }
    res.json(rows);
  } catch {
    res.json([]);
  }
});

app.get("/api/hooks", async (req, res) => {
  if (process.env.WORKBENCH_MODE !== "dev") return res.status(403).send("Forbidden");
  const mod = req.query.module as string | undefined;
  try {
    const pool: import("pg").Pool = container.resolve("pool");
    const { rows } = await pool.query(
      `SELECT * FROM workbench.api_hooks($1)`,
      [mod ?? null],
    );
    res.json(rows);
  } catch {
    res.json([]);
  }
});

app.get("/api/messages", async (req, res) => {
  if (process.env.WORKBENCH_MODE !== "dev") return res.status(403).send("Forbidden");
  const mod = req.query.module as string | undefined;
  try {
    const pool: import("pg").Pool = container.resolve("pool");
    const { rows } = await pool.query(
      `SELECT * FROM workbench.api_messages($1)`,
      [mod ?? null],
    );
    res.json(rows);
  } catch {
    res.json([]);
  }
});

// --- tmux session monitoring (read-only agent observation) ---
const tmuxWatchers = new Map<string, { tail: ChildProcess; clients: Set<WebSocket> }>();

app.get("/api/tmux", (_req, res) => {
  if (process.env.WORKBENCH_MODE !== "dev") return res.status(403).send("Forbidden");
  try {
    const raw = execFileSync("tmux", [
      "list-sessions", "-F",
      "#{session_name}\t#{session_created}\t#{session_activity}",
    ], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });

    const wsRoot = resolveWorkspaceRoot();
    const sessions = raw.trim().split("\n").filter(Boolean).map(line => {
      const [name, created, activity] = line.split("\t");
      let cwd = "";
      let dead = false;
      try {
        cwd = execFileSync("tmux", ["display-message", "-t", name, "-p", "#{pane_current_path}"], {
          encoding: "utf8", stdio: ["ignore", "pipe", "pipe"],
        }).trim();
        const info = execFileSync("tmux", ["list-panes", "-t", name, "-F", "#{pane_dead}"], {
          encoding: "utf8", stdio: ["ignore", "pipe", "pipe"],
        }).trim();
        dead = info === "1";
      } catch {}
      return { name, created: parseInt(created) * 1000, activity: parseInt(activity) * 1000, cwd, dead };
    }).filter(s => s.cwd.startsWith(wsRoot));

    res.json(sessions);
  } catch {
    res.json([]);
  }
});

function handleTmuxAttach(ws: WebSocket, session: string) {
  // Check session exists
  try {
    execFileSync("tmux", ["has-session", "-t", session], {
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch {
    ws.send(`\r\n\x1b[31mSession not found: ${session}\x1b[0m\r\n`);
    ws.close();
    return;
  }

  // Send initial scrollback (last 500 lines with ANSI escapes)
  try {
    const scrollback = execFileSync("tmux", [
      "capture-pane", "-p", "-e", "-t", session, "-S", "-500",
    ], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
    if (scrollback) ws.send(scrollback);
  } catch {}

  // Join or create watcher for this session
  let watcher = tmuxWatchers.get(session);
  if (!watcher) {
    const logPath = `/tmp/pgw-tmux-${session}.log`;
    fsSync.writeFileSync(logPath, "");

    // pipe-pane -o = output only (no input) → log file
    try {
      execFileSync("tmux", ["pipe-pane", "-o", "-t", session, `cat >> '${logPath}'`], {
        stdio: ["ignore", "pipe", "pipe"],
      });
    } catch {
      ws.send(`\r\n\x1b[31mFailed to attach pipe-pane: ${session}\x1b[0m\r\n`);
      ws.close();
      return;
    }

    // tail -f for event-driven streaming
    const tail = cpSpawn("tail", ["-f", logPath], {
      stdio: ["ignore", "pipe", "ignore"],
    });

    watcher = { tail, clients: new Set() };
    tmuxWatchers.set(session, watcher);

    tail.stdout?.on("data", (chunk: Buffer) => {
      const data = chunk.toString("utf8");
      for (const client of watcher!.clients) {
        if (client.readyState === 1) client.send(data);
      }
    });

    tail.on("exit", () => {
      tmuxWatchers.delete(session);
      try { fsSync.unlinkSync(logPath); } catch {}
    });
  }

  watcher.clients.add(ws);

  // Interactive: forward input to tmux, handle resize
  ws.on("message", (data: Buffer | string) => {
    const msg = typeof data === "string" ? data : data.toString();
    try {
      const parsed = JSON.parse(msg);
      if (parsed.type === "resize" && parsed.cols && parsed.rows) {
        const cols = Math.max(20, Math.floor(parsed.cols));
        const rows = Math.max(5, Math.floor(parsed.rows));
        try {
          execFileSync("tmux", ["resize-window", "-t", session, "-x", String(cols), "-y", String(rows)], {
            stdio: ["ignore", "pipe", "pipe"],
          });
        } catch {}
        return;
      }
    } catch {}
    // Forward raw input to tmux via send-keys (async to avoid blocking event loop)
    const parts = msg.split(/(\r\n|\r|\n)/);
    for (const part of parts) {
      if (!part) continue;
      if (part === "\r" || part === "\n" || part === "\r\n") {
        execFile("tmux", ["send-keys", "-t", session, "Enter"], () => {});
      } else {
        execFile("tmux", ["send-keys", "-t", session, "-l", "--", part], () => {});
      }
    }
  });

  ws.on("close", () => {
    watcher?.clients.delete(ws);
    if (watcher && watcher.clients.size === 0) {
      watcher.tail.kill();
      tmuxWatchers.delete(session);
      // Disable pipe-pane
      try {
        execFileSync("tmux", ["pipe-pane", "-t", session], {
          stdio: ["ignore", "pipe", "pipe"],
        });
      } catch {}
      try { fsSync.unlinkSync(`/tmp/pgw-tmux-${session}.log`); } catch {}
    }
  });
}

// --- Agent lifecycle: spawn / kill via tmux ---
// Env vars to strip to avoid Claude Code nesting issues
const CLAUDE_VARS_TO_STRIP = [
  "CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT", "CLAUDE_CODE_SESSION_ID",
  "CLAUDE_CODE_CONVERSATION_ID", "CLAUDE_CODE_TASK_ID",
  "NON_INTERACTIVE", "MCP_TRANSPORT", "MCP_SESSION_ID",
];

app.post("/api/agents/:module/spawn", async (req, res) => {
  if (process.env.WORKBENCH_MODE !== "dev") return res.status(403).send("Forbidden");
  const mod = req.params.module;
  const session = mod;

  // Already running?
  try {
    execFileSync("tmux", ["has-session", "-t", session], { stdio: ["ignore", "pipe", "pipe"] });
    return res.json({ status: "already_running", module: mod, session, ws: `/ws/tmux/${session}` });
  } catch {}

  const modPath = resolveModulePath(mod);
  if (!fsSync.existsSync(modPath)) {
    return res.status(404).json({ error: `Module not found: ${mod}` });
  }

  // Write spawn script (strips parent Claude env, launches claude CLI)
  const scriptFile = `/tmp/pgw-spawn-${session}.sh`;
  const script = [
    "#!/bin/sh",
    `unset ${CLAUDE_VARS_TO_STRIP.join(" ")}`,
    `exec claude`,
  ].join("\n");
  fsSync.writeFileSync(scriptFile, script, { mode: 0o700 });

  try {
    execFileSync("tmux", [
      "new-session", "-d", "-s", session, "-c", modPath, scriptFile,
    ], { stdio: ["ignore", "pipe", "pipe"] });
    execFileSync("tmux", ["set-option", "-t", session, "history-limit", "50000"], {
      stdio: ["ignore", "pipe", "pipe"],
    });
    execFileSync("tmux", ["set-option", "-t", session, "remain-on-exit", "on"], {
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return res.status(500).json({ error: msg });
  }

  // Track in DB
  const sessionId = await createAgentSession(mod);
  log.info({ mod, session, cwd: modPath }, "Spawned Claude agent in tmux");

  res.json({ status: "started", module: mod, session, sessionId, ws: `/ws/tmux/${session}` });
});

app.post("/api/agents/:module/kill", async (req, res) => {
  if (process.env.WORKBENCH_MODE !== "dev") return res.status(403).send("Forbidden");
  const mod = req.params.module;
  const session = mod;

  // Kill tmux session if exists
  try {
    execFileSync("tmux", ["has-session", "-t", session], { stdio: ["ignore", "pipe", "pipe"] });
    execFileSync("tmux", ["kill-session", "-t", session], { stdio: ["ignore", "pipe", "pipe"] });
    // Clean up watcher
    const watcher = tmuxWatchers.get(session);
    if (watcher) {
      watcher.tail.kill();
      for (const client of watcher.clients) client.close();
      tmuxWatchers.delete(session);
    }
    try { fsSync.unlinkSync(`/tmp/pgw-tmux-${session}.log`); } catch {}
    try { fsSync.unlinkSync(`/tmp/pgw-spawn-${session}.sh`); } catch {}
    log.info({ mod, session }, "Killed Claude agent tmux session");
    return res.json({ status: "killed", module: mod, session });
  } catch {}

  // Fallback: kill node-pty terminal
  const term = terminals.get(mod);
  if (!term) return res.json({ status: "not_running", module: mod });
  term.proc.kill();
  res.json({ status: "killed", module: mod });
});

httpServer.listen(PORT, async () => {
  log.info({ port: PORT }, "plpgsql-workbench MCP listening");

  // Log database connection at startup
  const connStr = process.env.PLPGSQL_CONNECTION ?? process.env.DATABASE_URL ?? "(default 5432)";
  const pool: import("pg").Pool = container.resolve("pool");
  try {
    const { rows } = await pool.query("SELECT version(), inet_server_addr()::text AS addr, inet_server_port() AS port");
    log.info({ db: rows[0].version.split(" on ")[0], addr: rows[0].addr, port: rows[0].port, connStr }, "Connected to database");
  } catch (err) {
    log.warn({ err, connStr }, "Could not connect to database");
  }
});
