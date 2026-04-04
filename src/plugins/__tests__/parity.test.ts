import { describe, expect, it } from "vitest";
import type { ToolHandler } from "../../core/container.js";
import { buildPluginContainer, type PluginManifest } from "../../core/plugin-registry.js";
import { ALL_PLUGINS } from "../index.js";

function buildAllPlugins() {
  const manifest: PluginManifest = { plugins: Object.fromEntries(ALL_PLUGINS.map((p) => [p.id, {}])) };
  return buildPluginContainer(manifest, ALL_PLUGINS);
}

describe("plugin registry", () => {
  it("registers all expected tools", () => {
    const { container } = buildAllPlugins();
    const registry: Map<string, ToolHandler> = container.resolve("toolRegistry");
    const names = [...registry.keys()].sort();

    // Spot-check key tools from each plugin
    expect(names).toContain("pg_query"); // pg-navigation
    expect(names).toContain("pg_func_set"); // pg-functions
    expect(names).toContain("plx_apply"); // pg-modules
    expect(names).toContain("runtime_apply"); // pg-runtime
    expect(names).toContain("pg_msg"); // pg-messaging
    expect(names).toContain("ws_health"); // pg-operations
    expect(names).toContain("fs_scan"); // docstore
    expect(names).toContain("gmail_search"); // google
    expect(names).toContain("doc_import"); // docman
    expect(names).toContain("doc_fetch_mail"); // docman (gmail capability)

    // Total count sanity
    expect(names.length).toBeGreaterThanOrEqual(60);

    container.dispose();
  });

  it("verifies requires constraints", () => {
    const manifest: PluginManifest = { plugins: { "pg-functions": {} } };
    expect(() => buildPluginContainer(manifest, ALL_PLUGINS)).toThrow(/requires "withClient"/);
  });

  it("tracks capabilities across plugins", () => {
    const { container } = buildAllPlugins();
    const caps: Set<string> = container.resolve("pluginCapabilities");
    expect(caps.has("database")).toBe(true);
    expect(caps.has("gmail")).toBe(true);
    container.dispose();
  });

  it("collects hook rules from plugins", () => {
    const { hookRules } = buildAllPlugins();
    expect(hookRules.length).toBeGreaterThan(0);
    // pg-navigation contributes pg_query rules
    const pgQueryRule = hookRules.find((r) => typeof r.toolPattern !== "string" && r.toolPattern.test("pg_query"));
    expect(pgQueryRule).toBeDefined();
  });
});
