#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import express from "express";
import { registerGet } from "./tools/get.js";
import { registerSearch } from "./tools/search.js";
import { registerSet } from "./tools/set.js";
import { registerEdit } from "./tools/edit.js";
import { registerTest } from "./tools/test.js";
import { registerQuery } from "./tools/query.js";
import { registerExplain } from "./tools/explain.js";
import { registerCoverage } from "./tools/coverage.js";
import { registerDump } from "./tools/dump.js";
import { registerApply } from "./tools/apply.js";
import { registerDoc } from "./tools/doc.js";

function createServer(): McpServer {
  const s = new McpServer({ name: "plpgsql-workbench", version: "0.1.0" });
  registerGet(s);
  registerSearch(s);
  registerSet(s);
  registerEdit(s);
  registerTest(s);
  registerQuery(s);
  registerExplain(s);
  registerCoverage(s);
  registerDump(s);
  registerApply(s);
  registerDoc(s);
  return s;
}

const PORT = parseInt(process.env.MCP_PORT ?? "3100", 10);

const app = express();
app.use(express.json());

app.post("/mcp", async (req, res) => {
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
    console.error("Error handling MCP request:", err);
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
  console.error(`plpgsql-workbench MCP listening on http://localhost:${PORT}/mcp`);
});
