/**
 * MCP Edge Function — Supabase deployment endpoint.
 *
 * Imports the shared core (container + packs) and serves MCP tools
 * via Streamable HTTP. In production, mounts only app packs (illustrator, etc.).
 * Auth via Supabase Auth (OAuth 2.0 Bearer token).
 */
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { buildContainer, mountTools, type ToolPack } from "../_shared/core/container.js";
import { plpgsqlPack } from "../_shared/core/packs/plpgsql.js";

// -- Packs to mount in production (add illustrator here later) --
const PACKS: Record<string, ToolPack> = {
  plpgsql: plpgsqlPack,
  // illustrator: illustratorPack,
};

const container = buildContainer(
  { packs: Object.fromEntries(Object.keys(PACKS).map(k => [k, {}])) },
  PACKS,
);

async function createServer(): Promise<McpServer> {
  const server = new McpServer({ name: "plpgsql-workbench", version: "0.1.0" });
  await mountTools(server, container);
  return server;
}

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  // Auth: validate Bearer token via Supabase Auth
  const token = req.headers.get("Authorization")?.replace("Bearer ", "");
  if (token) {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: `Bearer ${token}` } } },
    );
    const { error } = await supabase.auth.getUser();
    if (error) {
      return new Response("Unauthorized", { status: 401 });
    }
  }

  // MCP Streamable HTTP
  try {
    const body = await req.json();
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
    const server = await createServer();

    // Bridge: pipe transport output to a Response
    const { readable, writable } = new TransformStream();
    const writer = writable.getWriter();

    // Capture transport response
    const mockRes = {
      headersSent: false,
      statusCode: 200,
      _headers: new Map<string, string>(),
      setHeader(k: string, v: string) { this._headers.set(k, v); },
      getHeader(k: string) { return this._headers.get(k); },
      writeHead(status: number, headers?: Record<string, string>) {
        this.statusCode = status;
        if (headers) for (const [k, v] of Object.entries(headers)) this._headers.set(k, v);
        this.headersSent = true;
        return this;
      },
      write(chunk: string | Uint8Array) {
        const data = typeof chunk === "string" ? new TextEncoder().encode(chunk) : chunk;
        writer.write(data).catch(() => {});
        return true;
      },
      end(chunk?: string | Uint8Array) {
        if (chunk) this.write(chunk);
        writer.close().catch(() => {});
      },
      on() { return this; },
    };

    await server.connect(transport);
    await transport.handleRequest(
      { body, method: "POST", headers: Object.fromEntries(req.headers.entries()) } as any,
      mockRes as any,
      body,
    );

    await server.close();

    const responseHeaders = new Headers();
    for (const [k, v] of mockRes._headers) responseHeaders.set(k, v);
    responseHeaders.set("Access-Control-Allow-Origin", "*");

    return new Response(readable, {
      status: mockRes.statusCode,
      headers: responseHeaders,
    });
  } catch (err) {
    console.error("MCP error:", err);
    return new Response(
      JSON.stringify({
        jsonrpc: "2.0",
        error: { code: -32603, message: "Internal server error" },
        id: null,
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});
