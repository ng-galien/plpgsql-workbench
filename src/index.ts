#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import express from "express";
import pino from "pino";
import { buildContainer, mountTools, type ToolPack } from "./container.js";
import { plpgsqlPack } from "./packs/plpgsql.js";
import { docstorePack } from "./packs/docstore.js";
import { googlePack } from "./packs/google.js";

const log = pino({
  level: process.env.LOG_LEVEL ?? "info",
  transport: { target: "pino-pretty", options: { colorize: true } },
});

log.info("Building container...");

const packConfigs: Record<string, Record<string, unknown>> = {
  plpgsql: {},
  docstore: {},
};
const packImpls: Record<string, ToolPack> = {
  plpgsql: plpgsqlPack,
  docstore: docstorePack,
};

if (process.env.GOOGLE_CREDENTIALS_PATH) {
  packConfigs.google = {};
  packImpls.google = googlePack;
  log.info("Google pack enabled (GOOGLE_CREDENTIALS_PATH set)");
}

const container = buildContainer(
  { packs: packConfigs },
  packImpls,
);

const registry: Map<string, unknown> = container.resolve("toolRegistry");
log.info({ tools: [...registry.keys()], count: registry.size }, "Tools registered");

function createServer(): McpServer {
  const s = new McpServer({ name: "plpgsql-workbench", version: "0.1.0" });
  mountTools(s, container);
  return s;
}

const PORT = parseInt(process.env.MCP_PORT ?? "3100", 10);

const app = express();
app.use(express.json());

app.post("/mcp", async (req, res) => {
  log.debug({ method: req.body?.method }, "MCP request");
  const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
  const server = createServer();
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

app.get("/mcp", async (_req, res) => {
  res.writeHead(405).end("Method Not Allowed");
});

app.delete("/mcp", async (_req, res) => {
  res.writeHead(405).end("Method Not Allowed");
});

app.listen(PORT, () => {
  log.info({ port: PORT }, "plpgsql-workbench MCP listening");
});
