#!/usr/bin/env node
/**
 * workbench-channel.ts — Claude Code channel for plpgsql-workbench
 *
 * Two inputs:
 * 1. PG LISTEN — agent messages (pg_msg) arrive as NOTIFY → pushed to Claude session
 * 2. HTTP POST — browser annotations → pushed to Claude session
 *
 * One output:
 * - reply tool → pg_broadcast (Supabase Realtime → browser toast/navigate)
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import pg from "pg";

// --- Config ---
const PG_CONNECTION =
  process.env.PLPGSQL_CONNECTION ||
  process.env.DATABASE_URL ||
  "postgresql://postgres:postgres@localhost:5433/postgres";
const HTTP_PORT = parseInt(process.env.CHANNEL_PORT || "8789", 10);
const MODULE = process.env.MODULE || "lead";
const PG_CHANNEL = `workbench_channel_${MODULE}`;

// --- MCP Server ---
const mcp = new Server(
  { name: "workbench", version: "0.1.0" },
  {
    capabilities: {
      experimental: { "claude/channel": {} },
      tools: {},
    },
    instructions: `Events from the workbench channel arrive as <channel source="workbench" ...>.

Two types of events:
1. Agent messages: <channel source="workbench" type="pg_msg" from="document" msg_type="info" priority="normal">subject text</channel>
   → An agent module sent you a message. Read it, decide what to do, and optionally reply.

2. Browser annotations: <channel source="workbench" type="annotation" element_id="title" page="/docs/document/42">user feedback text</channel>
   → The user annotated an element in the browser preview. Process the feedback.

To reply to the browser (toast, navigate), use the broadcast tool.
To reply to an agent, use pg_msg via your MCP tools.`,
  }
);

// --- Reply tool: broadcast to browser ---
mcp.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "broadcast",
      description:
        "Send a notification to the browser (toast with optional link, or navigation command)",
      inputSchema: {
        type: "object" as const,
        properties: {
          msg: { type: "string", description: "Toast message" },
          detail: { type: "string", description: "Toast subtitle" },
          href: { type: "string", description: "Link URL" },
          level: {
            type: "string",
            enum: ["info", "success", "warning", "error"],
            description: "Toast level",
          },
          action: {
            type: "string",
            enum: ["navigate"],
            description: "navigate = auto-navigate, no toast",
          },
        },
        required: ["msg"],
      },
    },
  ],
}));

mcp.setRequestHandler(CallToolRequestSchema, async (req) => {
  if (req.params.name === "broadcast") {
    const payload = req.params.arguments as Record<string, string>;
    // Use Supabase broadcast via PG notify (the MCP server picks it up)
    const client = new pg.Client(PG_CONNECTION);
    await client.connect();
    await client.query("SELECT pg_notify('workbench_broadcast', $1)", [
      JSON.stringify(payload),
    ]);
    await client.end();
    return { content: [{ type: "text", text: `broadcast: ${payload.msg}` }] };
  }
  throw new Error(`unknown tool: ${req.params.name}`);
});

// --- Connect to Claude Code ---
await mcp.connect(new StdioServerTransport());

// --- PG LISTEN for agent messages ---
const pgClient = new pg.Client(PG_CONNECTION);
await pgClient.connect();
await pgClient.query(`LISTEN ${PG_CHANNEL}`);

pgClient.on("notification", async (msg) => {
  if (msg.channel !== PG_CHANNEL || !msg.payload) return;
  try {
    const data = JSON.parse(msg.payload);
    await mcp.notification({
      method: "notifications/claude/channel",
      params: {
        content: data.subject || data.body || msg.payload,
        meta: {
          type: "pg_msg",
          from: data.from_module || "unknown",
          msg_type: data.msg_type || "info",
          priority: data.priority || "normal",
          msg_id: String(data.id || ""),
        },
      },
    });
  } catch {
    // Raw text notification
    await mcp.notification({
      method: "notifications/claude/channel",
      params: { content: msg.payload, meta: { type: "pg_msg" } },
    });
  }
});

// --- HTTP server for browser annotations ---
const http = await import("node:http");
const server = http.createServer(async (req, res) => {
  if (req.method !== "POST") {
    res.writeHead(405);
    res.end("Method not allowed");
    return;
  }

  const chunks: Buffer[] = [];
  for await (const chunk of req) chunks.push(chunk as Buffer);
  const body = Buffer.concat(chunks).toString();

  try {
    const data = JSON.parse(body);
    await mcp.notification({
      method: "notifications/claude/channel",
      params: {
        content: data.message || data.text || body,
        meta: {
          type: "annotation",
          element_id: data.element_id || "",
          page: data.page || "",
          user: data.user || "anonymous",
        },
      },
    });
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true }));
  } catch {
    res.writeHead(400);
    res.end("Invalid JSON");
  }
});

server.listen(HTTP_PORT, "127.0.0.1", () => {
  // stderr so it doesn't interfere with stdio transport
  console.error(`[workbench-channel] module=${MODULE} HTTP=:${HTTP_PORT} PG=${PG_CHANNEL}`);
});
