/**
 * MCP Edge Function — Supabase deployment endpoint.
 *
 * McpServer is a singleton (tools registered once at boot).
 * Transport is per-request (stateless, as required by the SDK).
 * Uses postgres.js driver for direct SQL via SUPABASE_DB_URL.
 */
import "@supabase/functions-js/edge-runtime.d.ts";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { WebStandardStreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/webStandardStreamableHttp.js";
import { asFunction, asValue } from "awilix";
import type { ToolPack } from "../_shared/core/container.js";
import { buildContainer, mountTools } from "../_shared/core/container.js";
import { createPostgresWithClient } from "../_shared/core/drivers/supabase.js";
import { createQueryTool } from "../_shared/core/tools/plpgsql/query.js";
import { illustratorPack } from "../_shared/core/packs/illustrator.js";
import postgres from "postgres";

// -- Database connection (singleton, with timeouts) --
const dbUrl = Deno.env.get("SUPABASE_DB_URL")
  ?? Deno.env.get("PLPGSQL_CONNECTION")
  ?? "postgresql://postgres:postgres@localhost:54322/postgres";

const sql = postgres(dbUrl, {
  idle_timeout: 20,       // close idle connections after 20s
  connect_timeout: 10,    // fail fast if PG unreachable
  max: 5,                 // connection pool size
});
const withClient = createPostgresWithClient(sql);

// -- Edge pack: supabase driver + pg_query --
const edgePack: ToolPack = (container, _config) => {
  container.register({
    withClient: asValue(withClient),
    queryTool: asFunction(createQueryTool).singleton(),
  });
};

// -- Singleton: container + server built once at boot --
const container = buildContainer(
  { packs: { edge: {}, illustrator: {} } },
  { edge: edgePack, illustrator: illustratorPack },
);

const server = new McpServer({ name: "plpgsql-workbench-edge", version: "0.1.0" });
await mountTools(server, container);

// -- CORS headers --
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, Accept, Mcp-Session-Id",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS });
  }

  // Per-request: fresh transport only (server is singleton)
  try {
    const transport = new WebStandardStreamableHTTPServerTransport();
    await server.connect(transport);
    return await transport.handleRequest(req);
  } catch (err) {
    // Client disconnect (EOF), timeout, or transport error — log and return clean error
    const msg = err instanceof Error ? err.message : String(err);
    if (msg.includes("EOF") || msg.includes("connection")) {
      // Client disconnected mid-stream — not a real error
      console.warn("Client disconnected:", msg);
      return new Response(null, { status: 499 }); // nginx-style "client closed"
    }
    console.error("MCP error:", err);
    return new Response(
      JSON.stringify({
        jsonrpc: "2.0",
        error: { code: -32603, message: "Internal server error" },
        id: null,
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
