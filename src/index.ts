#!/usr/bin/env node

import http from "node:http";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import express from "express";
import pino from "pino";

import { mountTools } from "./core/container.js";
import { buildPluginContainer } from "./core/plugin-registry.js";
import { ALL_PLUGINS } from "./plugins/index.js";
import { loadConfig, resolveManifest } from "./server/config.js";
import { mountDevEndpoints } from "./server/dev.js";
import { mountHooks } from "./server/hooks.js";
import { mountTerminal } from "./server/terminal.js";

const log = pino({
  level: process.env.LOG_LEVEL ?? "info",
  transport: { target: "pino-pretty", options: { colorize: true } },
});

// --- Bootstrap ---

const appConfig = loadConfig(log);

if (appConfig.connection) {
  process.env.PLPGSQL_CONNECTION = appConfig.connection;
}

const manifest = resolveManifest(appConfig, log);
log.info({ app: appConfig.name, plugins: Object.keys(manifest.plugins) }, "Building container");

const { container, hookRules } = buildPluginContainer(manifest, ALL_PLUGINS);

const registry: Map<string, unknown> = container.resolve("toolRegistry");
log.info({ tools: [...registry.keys()], count: registry.size }, "Tools registered");

// Resolve moduleRegistry once at startup
let moduleRegistry: import("./core/pgm/registry.js").ModuleRegistry | null = null;
const moduleRegistryPromise: Promise<import("./core/pgm/registry.js").ModuleRegistry> =
  container.resolve("moduleRegistry");
moduleRegistryPromise
  .then((r) => {
    moduleRegistry = r;
  })
  .catch(() => {});

// --- Express + MCP ---

async function createServer(): Promise<McpServer> {
  const s = new McpServer({ name: "plpgsql-workbench", version: "0.1.0" });
  await mountTools(s, container);
  return s;
}

const PORT = appConfig.port ?? parseInt(process.env.MCP_PORT ?? "3100", 10);

const app = express();
app.use((_req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Content-Type, Content-Profile, Accept");
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  if (_req.method === "OPTIONS") return res.sendStatus(204);
  next();
});
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

  res.on("close", () => {
    void closeAll();
  });

  try {
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
  } catch (err) {
    log.error(err, "Error handling MCP request");
    if (!res.headersSent) {
      res.status(500).json({ jsonrpc: "2.0", error: { code: -32603, message: "Internal server error" }, id: null });
    } else if (!res.writableEnded) {
      res.end();
    }
  } finally {
    await closeAll();
  }
});

app.get("/mcp", async (_req, res) => {
  res.writeHead(405).end("Method Not Allowed");
});
app.delete("/mcp", async (_req, res) => {
  res.writeHead(405).end("Method Not Allowed");
});

// --- Mount server modules ---

mountHooks(app, { container, hookRules, getModuleRegistry: () => moduleRegistry, log });
mountDevEndpoints(app, container);

const httpServer = http.createServer(app);
mountTerminal(httpServer, app, { container, log });

// --- Listen ---

httpServer.listen(PORT, async () => {
  log.info({ port: PORT }, "plpgsql-workbench MCP listening");
  const connStr = process.env.PLPGSQL_CONNECTION ?? process.env.DATABASE_URL ?? "(default 5432)";
  const pool: import("pg").Pool = container.resolve("pool");
  try {
    const { rows } = await pool.query("SELECT version(), inet_server_addr()::text AS addr, inet_server_port() AS port");
    log.info(
      { db: rows[0].version.split(" on ")[0], addr: rows[0].addr, port: rows[0].port, connStr },
      "Connected to database",
    );
  } catch (err) {
    log.warn({ err, connStr }, "Could not connect to database");
  }
});

function shutdown(signal: string) {
  log.info({ signal }, "Shutting down");
  httpServer.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 3000).unref();
}
process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
