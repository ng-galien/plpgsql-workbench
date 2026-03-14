/**
 * MCP Illustrator — Cloudflare Worker
 *
 * Single deployment: MCP server + Stripe billing endpoints.
 * Auth: Supabase JWT (all routes except /webhook).
 * MCP: Streamable HTTP via @modelcontextprotocol/sdk.
 *
 * Imports core pack from ../../src/core/ (compiled to ../../dist/core/).
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { WebStandardStreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/webStandardStreamableHttp.js";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { asFunction, asValue } from "awilix";
import type { ToolPack } from "../../../src/core/container.js";
import { buildContainer, mountTools } from "../../../src/core/container.js";
import { createPostgresWithClient } from "../../../src/core/drivers/supabase.js";
import { illustratorPack } from "../../../src/core/packs/illustrator.js";
import { createQueryTool } from "../../../src/core/tools/plpgsql/query.js";
import postgres from "postgres";

export interface Env {
	SUPABASE_URL: string;
	SUPABASE_JWT_SECRET: string;
	SUPABASE_SERVICE_ROLE_KEY: string;
	STRIPE_SECRET_KEY: string;
	STRIPE_WEBHOOK_SECRET: string;
	STRIPE_PRICE_PRO: string;
	STRIPE_PRICE_TEAM: string;
	DATABASE_URL: string;
}

const app = new Hono<{ Bindings: Env }>();

// --- Database + container (per-request — Cloudflare Workers can't share I/O across requests) ---
function getContainer(env: Env) {
	const sql = postgres(env.DATABASE_URL, {
		idle_timeout: 10,
		connect_timeout: 5,
		max: 1,
	});
	const withClient = createPostgresWithClient(sql, { tenantId: "dev" });

	const edgePack: ToolPack = (container, _config) => {
		container.register({
			withClient: asValue(withClient),
			queryTool: asFunction(createQueryTool).singleton(),
		});
	};

	return buildContainer(
		{ packs: { edge: {}, illustrator: {} } },
		{ edge: edgePack, illustrator: illustratorPack },
	);
}

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
	if (c.req.path === "/webhook") return next();
	if (c.req.method === "HEAD" || c.req.method === "GET") return next();

	const token = c.req.header("Authorization")?.replace("Bearer ", "");
	if (!token) {
		if (!c.env.SUPABASE_JWT_SECRET) return next();
		return c.json({ error: "Unauthorized" }, 401);
	}

	// TODO: Verify Supabase JWT (jose library)
	await next();
});

// --- POST / → MCP Server ---
app.post("/", async (c) => {
	const container = getContainer(c.env);

	const server = new McpServer({
		name: "mcp-illustrator",
		version: "1.0.0",
	});
	await mountTools(server, container);

	const transport = new WebStandardStreamableHTTPServerTransport();
	await server.connect(transport);
	return transport.handleRequest(c.req.raw);
});

// --- POST /checkout → Stripe Checkout ---
app.post("/checkout", async (c) => {
	return c.json({ error: "Not implemented" }, 501);
});

// --- POST /portal → Stripe Customer Portal ---
app.post("/portal", async (c) => {
	return c.json({ error: "Not implemented" }, 501);
});

// --- Fallback ---
app.all("*", (c) => {
	return c.text("Not Found", 404);
});

export default app;
