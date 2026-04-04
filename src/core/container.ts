/**
 * container.ts — Awilix DI container for composable tool packs.
 *
 * Everything is injected: pool, withClient, shared services, tools.
 * Dependencies are resolved by parameter name via Awilix PROXY mode.
 */

import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { RequestHandlerExtra } from "@modelcontextprotocol/sdk/shared/protocol.js";
import type { ServerNotification, ServerRequest } from "@modelcontextprotocol/sdk/types.js";
import type { AwilixContainer } from "awilix";
import type { z } from "zod";
import type { DbClient } from "./connection.js";
import type { ToolResult } from "./helpers.js"; // used by ToolHandler

// --- Core types ---

export type WithClient = <T>(fn: (client: DbClient) => Promise<T>) => Promise<T>;

/** MCP extra context passed to tool handlers (signal, sendNotification, etc.). */
export type ToolExtra = RequestHandlerExtra<ServerRequest, ServerNotification>;

export interface ToolMetadata {
  name: string;
  description: string;
  schema: z.ZodObject<any>;
}

export interface ToolHandler {
  metadata: ToolMetadata;
  handler: (args: Record<string, unknown>, extra: ToolExtra) => Promise<ToolResult>;
}

// --- MCP mounting ---

/**
 * Register tools from the container onto an McpServer.
 * In dev mode (WORKBENCH_MODE=dev or no toolbox table): mounts all tools.
 * Otherwise: mounts only tools from the specified toolbox.
 */
export async function mountTools(server: McpServer, container: AwilixContainer, toolbox?: string): Promise<void> {
  const registry: Map<string, ToolHandler> = container.resolve("toolRegistry");
  const withClient: WithClient = container.resolve("withClient");

  let allowedTools: Set<string> | null = null;

  if (process.env.WORKBENCH_MODE !== "dev") {
    try {
      const toolNames = await withClient(async (client) => {
        const box = toolbox ?? "admin";
        const res = await client.query(`SELECT tool_name FROM workbench.toolbox_tool WHERE toolbox_name = $1`, [box]);
        return res.rows.map((r: { tool_name: string }) => r.tool_name);
      });
      if (toolNames.length > 0) {
        allowedTools = new Set(toolNames);
      }
    } catch (err: unknown) {
      // Only swallow "undefined table" — surface real DB errors
      const code = (err as { code?: string })?.code;
      if (code !== "42P01") throw err;
      // Table doesn't exist yet — mount everything
    }
  }

  for (const [, tool] of registry) {
    if (allowedTools && !allowedTools.has(tool.metadata.name)) continue;
    server.tool(
      tool.metadata.name,
      tool.metadata.description,
      tool.metadata.schema.shape,
      async (args: Record<string, unknown>, extra: ToolExtra) => {
        return await tool.handler(args, extra);
      },
    );
  }
}
