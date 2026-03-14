/**
 * MCP Illustrator — Cloudflare Worker
 *
 * Single deployment: MCP server + Stripe billing endpoints.
 * Auth: Supabase JWT (all routes except /webhook).
 * MCP: Streamable HTTP via @modelcontextprotocol/sdk.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { WebStandardStreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/webStandardStreamableHttp.js";
import { Hono } from "hono";
import { cors } from "hono/cors";

export interface Env {
	SUPABASE_URL: string;
	SUPABASE_JWT_SECRET: string;
	SUPABASE_SERVICE_ROLE_KEY: string;
	STRIPE_SECRET_KEY: string;
	STRIPE_WEBHOOK_SECRET: string;
	STRIPE_PRICE_PRO: string;
	STRIPE_PRICE_TEAM: string;
	DATABASE_URL: string; // Supabase PG direct connection
}

const app = new Hono<{ Bindings: Env }>();

// --- CORS ---
app.use("*", cors({
	origin: "*",
	allowMethods: ["GET", "POST", "HEAD", "OPTIONS", "DELETE"],
	allowHeaders: ["Content-Type", "Authorization", "Accept", "Mcp-Session-Id"],
}));

// --- HEAD / → Claude Store protocol version ---
app.get("/", (c) => {
	return c.body(null, 200, {
		"MCP-Protocol-Version": "2025-06-18",
	});
});

// --- POST /webhook → Stripe (signature only, no JWT) ---
app.post("/webhook", async (c) => {
	// TODO: Stripe webhook handler
	return c.json({ received: true });
});

// --- JWT verification middleware (all other routes) ---
app.use("*", async (c, next) => {
	// Skip for webhook and HEAD (already handled)
	if (c.req.path === "/webhook") return next();
	if (c.req.method === "HEAD") return next();

	const token = c.req.header("Authorization")?.replace("Bearer ", "");
	if (!token) {
		// In dev, allow unauthenticated access
		if (!c.env.SUPABASE_JWT_SECRET) return next();
		return c.json({ error: "Unauthorized" }, 401);
	}

	// TODO: Verify Supabase JWT
	// For now, pass through (dev mode)
	await next();
});

// --- POST / → MCP Server ---
app.post("/", async (c) => {
	const server = new McpServer({
		name: "mcp-illustrator",
		version: "1.0.0",
	});

	// Register tools from our core pack
	// TODO: Import and mount illustrator tools from src/core/
	// For now, a test tool
	server.registerTool(
		"ill_ping",
		{
			description: "Test tool — returns pong",
			inputSchema: {},
			annotations: { readOnlyHint: true },
		},
		async () => ({
			content: [{ type: "text" as const, text: "pong from Cloudflare Worker" }],
		}),
	);

	const transport = new WebStandardStreamableHTTPServerTransport();
	await server.connect(transport);
	return transport.handleRequest(c.req.raw);
});

// --- POST /checkout → Stripe Checkout ---
app.post("/checkout", async (c) => {
	// TODO: Stripe checkout session
	return c.json({ error: "Not implemented" }, 501);
});

// --- POST /portal → Stripe Customer Portal ---
app.post("/portal", async (c) => {
	// TODO: Stripe portal session
	return c.json({ error: "Not implemented" }, 501);
});

// --- Fallback ---
app.all("*", (c) => {
	return c.text("Not Found", 404);
});

export default app;
