/**
 * plugin.ts — Explicit plugin contract for the workbench.
 *
 * A plugin is a plain object that declares what it brings (services, tools,
 * hook rules) and what it needs (requires). No abstract class, no framework.
 */

import type { AwilixContainer } from "awilix";

// --- Plugin contract ---

export type PluginConfig = Record<string, unknown>;

export interface Plugin {
  /** Unique identifier, kebab-case. E.g. "pg-database", "pg-modules" */
  readonly id: string;

  /** Human-readable name for logs and diagnostics. */
  readonly name: string;

  /**
   * Awilix registration names this plugin requires before it runs.
   * Checked at load time — missing dependency = hard error.
   */
  readonly requires?: string[];

  /**
   * Capability tokens this plugin provides.
   * Used for optional cross-plugin detection (e.g. docman checking for "gmail").
   */
  readonly capabilities?: string[];

  /** Register services and tools into the DI container. */
  register(container: AwilixContainer, config: PluginConfig): void;

  /** Contribute hook rules for workflow enforcement. */
  hooks?: () => HookRule[];
}

// --- Hook system ---

export interface HookContext {
  /** Module name from the hook endpoint URL. */
  module: string;
  /** MCP tool name being called. */
  toolName: string;
  /** Tool input arguments. */
  toolInput: Record<string, unknown>;
  /** Schemas owned by the calling module (empty if unknown). */
  schemas: string[];
}

export interface HookRule {
  /** Which tool(s) this rule applies to. */
  toolPattern: string | RegExp;
  /** Return null to pass-through, or a decision to deny/allow. */
  evaluate(ctx: HookContext): HookDecision | null;
}

export type HookDecision = { action: "deny"; reason: string } | { action: "allow"; additionalContext?: string };

// --- Helpers ---

/** Extract a string field from tool input, defaulting to empty string. */
export function inputStr(ctx: HookContext, key: string): string {
  return (ctx.toolInput[key] ?? "") as string;
}

/** Check whether a tool name matches a HookRule pattern. */
export function matchesToolPattern(toolName: string, pattern: string | RegExp): boolean {
  if (typeof pattern === "string") return toolName === pattern;
  return pattern.test(toolName);
}
