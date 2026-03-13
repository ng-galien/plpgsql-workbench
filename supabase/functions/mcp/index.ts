/**
 * MCP Edge Function — Supabase deployment endpoint.
 *
 * Per-request stateless: transport + server.connect created for each request.
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
import postgres from "postgres";

// -- Database connection (singleton, reused across requests) --
const dbUrl = Deno.env.get("SUPABASE_DB_URL")
  ?? Deno.env.get("PLPGSQL_CONNECTION")
  ?? "postgresql://postgres:postgres@localhost:54322/postgres";

const sql = postgres(dbUrl);
const withClient = createPostgresWithClient(sql);

// -- Edge pack: supabase driver + tools --
const edgePack: ToolPack = (container, _config) => {
  container.register({
    withClient: asValue(withClient),
    queryTool: asFunction(createQueryTool).singleton(),
  });
};

// Container is built once (singleton)
const container = buildContainer(
  { packs: { edge: {} } },
  { edge: edgePack },
);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, GET, DELETE, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, Accept, Mcp-Session-Id",
      },
    });
  }

  // Per-request: fresh server + transport (stateless, as required by the SDK)
  const server = new McpServer({ name: "plpgsql-workbench-edge", version: "0.1.0" });
  await mountTools(server, container);

  const transport = new WebStandardStreamableHTTPServerTransport();
  await server.connect(transport);

  return transport.handleRequest(req);
});
