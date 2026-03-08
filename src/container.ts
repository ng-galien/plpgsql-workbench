/**
 * container.ts — Awilix DI container for composable tool packs.
 *
 * Everything is injected: pool, withClient, shared services, tools.
 * Dependencies are resolved by parameter name via Awilix PROXY mode.
 */

import { createContainer, asValue, type AwilixContainer } from "awilix";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { RequestHandlerExtra } from "@modelcontextprotocol/sdk/shared/protocol.js";
import type { ServerRequest, ServerNotification } from "@modelcontextprotocol/sdk/types.js";
import type { DbClient } from "./connection.js";
import type { ToolResult } from "./helpers.js";  // used by ToolHandler
import { z } from "zod";

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

/** A pack registers services and tools into the container. */
export type ToolPack = (container: AwilixContainer, config: Record<string, unknown>) => void;

/** Profile: which packs to load + their config. */
export interface WorkbenchProfile {
  packs: Record<string, Record<string, unknown>>;
}

// --- Container builder ---

export function buildContainer(profile: WorkbenchProfile, packs: Record<string, ToolPack>): AwilixContainer {
  const container = createContainer({ strict: true });

  // Register each requested pack
  for (const [name, config] of Object.entries(profile.packs)) {
    const pack = packs[name];
    if (!pack) throw new Error(`Unknown pack: ${name}`);
    pack(container, config);
  }

  // Resolve only tool registrations (named *Tool) to avoid eagerly creating
  // infrastructure like the DB pool at startup.
  const registry = new Map<string, ToolHandler>();
  for (const name of Object.keys(container.registrations)) {
    if (!name.endsWith("Tool")) continue;
    const val = container.resolve(name);
    if (isToolHandler(val)) {
      registry.set(val.metadata.name, val);
    }
  }

  container.register({
    toolRegistry: asValue(registry),
  });

  return container;
}

// --- MCP mounting ---

/** Register all tools from the container onto an McpServer. */
export function mountTools(server: McpServer, container: AwilixContainer): void {
  const registry: Map<string, ToolHandler> = container.resolve("toolRegistry");
  for (const [, tool] of registry) {
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

// --- Guard ---

function isToolHandler(val: unknown): val is ToolHandler {
  return (
    typeof val === "object" && val !== null &&
    "metadata" in val && "handler" in val &&
    typeof (val as any).metadata?.name === "string" &&
    typeof (val as any).handler === "function"
  );
}
