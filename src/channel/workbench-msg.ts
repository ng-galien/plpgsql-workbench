#!/usr/bin/env node
/**
 * workbench-msg.ts — Claude Code channel for plpgsql-workbench
 *
 * Listens for agent_message and issue_report changes via Supabase Realtime (CDC).
 * Pushes relevant messages to the Claude session.
 * Provides a broadcast tool to send toasts/navigation to the browser.
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { createClient } from "@supabase/supabase-js";

// --- Config ---
const SUPABASE_URL = process.env.SUPABASE_URL || "http://localhost:54321";
const SUPABASE_KEY =
  process.env.SUPABASE_ANON_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
const MODULE = process.env.MODULE || "lead";

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// --- MCP Server ---
const mcp = new Server(
  { name: "workbench-msg", version: "0.2.0" },
  {
    capabilities: {
      experimental: { "claude/channel": {} },
      tools: {},
    },
    instructions: `Events from the workbench channel arrive as <channel source="workbench" ...>.

CRITICAL: When you receive a channel event, ACT ON IT IMMEDIATELY. Do not wait for user input. Read the message with pg_msg_inbox, process it, and resolve it. You are an autonomous agent — channel events are your work queue.

Two types of events:
1. Agent messages: <channel source="workbench" type="pg_msg" from="lead" msg_type="task" priority="high" msg_id="42">subject text</channel>
   → A task or message for you. Read it with pg_msg_inbox, execute the task, then resolve it.

2. Issue reports: <channel source="workbench" type="issue" issue_id="42" module="lead">description</channel>
   → A user reported an issue. Read it with: SELECT * FROM workbench.issue_report WHERE id = <issue_id>. Fix it.

To reply to the browser (toast, navigate), use the broadcast tool.
To reply to an agent, use pg_msg via your MCP tools.`,
  },
);

// --- Reply tool: broadcast to browser via Supabase Realtime ---
mcp.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "broadcast",
      description: "Send a notification to the browser (toast with optional link, or navigation command)",
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
    const channel = supabase.channel("ai-activity");
    await channel.send({
      type: "broadcast",
      event: "activity",
      payload,
    });
    supabase.removeChannel(channel);
    return { content: [{ type: "text", text: `broadcast: ${payload.msg}` }] };
  }
  throw new Error(`unknown tool: ${req.params.name}`);
});

// --- Connect to Claude Code ---
await mcp.connect(new StdioServerTransport());

// --- Supabase Realtime: listen for agent_message inserts ---
supabase
  .channel("agent-messages")
  .on(
    "postgres_changes",
    {
      event: "INSERT",
      schema: "workbench",
      table: "agent_message",
      filter: `to_module=eq.${MODULE}`,
    },
    async (payload) => {
      const row = payload.new as Record<string, unknown>;
      await mcp.notification({
        method: "notifications/claude/channel",
        params: {
          content: String(row.subject || row.body || ""),
          meta: {
            type: "pg_msg",
            from: String(row.from_module || "unknown"),
            msg_type: String(row.msg_type || "info"),
            priority: String(row.priority || "normal"),
            msg_id: String(row.id || ""),
          },
        },
      });
    },
  )
  .subscribe((status) => {
    console.error(`[workbench-msg] module=${MODULE} agent_message: ${status}`);
  });

// issue_report triggers insert into agent_message — no separate subscription needed

console.error(`[workbench-msg] module=${MODULE} ready (Supabase Realtime)`);
