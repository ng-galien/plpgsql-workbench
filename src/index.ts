#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import express from "express";
import fsSync from "fs";
import fs from "fs/promises";
import os from "os";
import path from "path";
import pino from "pino";
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
// Detect cross-module calls to _prefix internal functions in SQL body
const INTERNAL_CALL_RE = /\b(\w+)\._(\w+)\s*\(/g;

// moduleRegistry is registered as a Promise — await it once at startup
let moduleRegistry: import("./pgm/registry.js").ModuleRegistry | null = null;
const moduleRegistryPromise: Promise<import("./pgm/registry.js").ModuleRegistry> = container.resolve("moduleRegistry");
moduleRegistryPromise.then((r) => { moduleRegistry = r; }).catch(() => {});

function deny(res: import("express").Response, reason: string) {
  res.json({ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: reason } });
}
function allow(res: import("express").Response) {
  res.json({ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "allow" } });
}

app.post("/hooks/:module", (req, res) => {
  const mod = req.params.module;
  const { tool_name, tool_input } = req.body ?? {};
  if (!moduleRegistry) {
    // Registry not loaded yet — allow (fail-open during startup)
    return allow(res);
  }
  const mapping = moduleRegistry.resolve([mod]) ?? moduleRegistry.resolve([`${mod}_ut`]);
  const schemas = mapping?.schemas ?? [mod];

  // Rule: pg_query must not do DDL, function management, or destructive ops
  if (tool_name === "mcp__plpgsql-workbench__pg_query") {
    const sql = (tool_input?.sql ?? "") as string;
    if (FUNC_PATTERN.test(sql)) {
      log.warn({ mod, sql: sql.slice(0, 80) }, "hook: blocked CREATE FUNCTION in pg_query");
      return deny(res, "pg_query interdit pour les fonctions. Utilise pg_func_set + pg_test.\n\n" + WORKFLOW);
    }
    if (DDL_PATTERN.test(sql)) {
      log.warn({ mod, sql: sql.slice(0, 80) }, "hook: blocked DDL in pg_query");
      return deny(res, "pg_query interdit pour le DDL. Ecris un fichier SQL + pg_schema.\n\n" + WORKFLOW);
    }
    if (DESTRUCTIVE_PATTERN.test(sql)) {
      log.warn({ mod, sql: sql.slice(0, 80) }, "hook: blocked destructive op in pg_query");
      return deny(res, "pg_query interdit pour DROP FUNCTION / TRUNCATE / GRANT / REVOKE. Utilise les outils dedies.\n\n" + WORKFLOW);
    }
  }

  // Rule: Write/Edit must stay within module directory and respect workflow
  if (tool_name === "Write" || tool_name === "Edit") {
    const filePath = path.resolve((tool_input?.file_path ?? "") as string);
    const content = (tool_input?.content ?? tool_input?.new_string ?? "") as string;
    const modulePath = mapping?.modulePath;
    if (modulePath && !filePath.startsWith(path.resolve(modulePath))) {
      log.warn({ mod, file: filePath, allowed: modulePath }, "hook: blocked file op outside module");
      return deny(res, `Module ${mod}: ${tool_name} interdit hors du repertoire du module (${modulePath}). Travaille uniquement dans le repertoire du module.`);
    }
    if (filePath.endsWith(".func.sql")) {
      log.warn({ mod, file: filePath }, "hook: blocked direct write to .func.sql");
      return deny(res, "*.func.sql est genere par pg_pack. Utilise pg_func_set pour iterer, puis pg_pack pour exporter.\n\n" + WORKFLOW);
    }
    if (tool_name === "Write" && filePath.endsWith(".sql") && FUNC_PATTERN.test(content)) {
      log.warn({ mod, file: filePath }, "hook: blocked Write of SQL function file");
      return deny(res, "Interdit d'ecrire des fonctions dans des fichiers SQL. Utilise pg_func_set + pg_test, puis pg_func_save quand stable.\n\n" + WORKFLOW);
    }
  }

  // Rule: pg_func_set must target a schema owned by this module
  if (tool_name === "mcp__plpgsql-workbench__pg_func_set") {
    const schema = (tool_input?.schema ?? "") as string;
    if (schema && !schemas.includes(schema)) {
      log.warn({ mod, schema, allowed: schemas }, "hook: blocked cross-module pg_func_set");
      return deny(res, `Module ${mod}: pg_func_set interdit sur le schema '${schema}'. Schemas autorises: ${schemas.join(", ")}`);
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
      return deny(res, `Module ${mod}: appel a des fonctions internes d'un autre module interdit.\nViolations: ${internalCalls.join(", ")}\n\nConvention: schema._name() = interne, cross-module interdit.`);
    }
    // pgv-specific: no inline styles
    if (schema === "pgv" && /style\s*=\s*"/.test(body)) {
      log.warn({ mod }, "hook: blocked inline style in pgv function");
      return deny(res, "Les fonctions pgv ne doivent pas contenir de style inline (style=\"...\"). Utilise class=\"pgv-*\" et definis les styles dans pgview.css.");
    }
  }

  // Rule: pg_func_edit must target a schema owned by this module
  if (tool_name === "mcp__plpgsql-workbench__pg_func_edit") {
    const schema = (tool_input?.schema ?? "") as string;
    if (schema && !schemas.includes(schema)) {
      log.warn({ mod, schema, allowed: schemas }, "hook: blocked cross-module pg_func_edit");
      return deny(res, `Module ${mod}: pg_func_edit interdit sur le schema '${schema}'. Schemas autorises: ${schemas.join(", ")}`);
    }
  }

  allow(res);
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

app.get("/mcp", async (_req, res) => {
  res.writeHead(405).end("Method Not Allowed");
});

app.delete("/mcp", async (_req, res) => {
  res.writeHead(405).end("Method Not Allowed");
});

app.listen(PORT, async () => {
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
