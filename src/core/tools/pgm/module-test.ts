import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";
import type { ModuleRegistry } from "../../pgm/registry.js";
import { loadManifest } from "../../pgm/resolver.js";
import { formatReadDocument } from "../../tooling/primitives/read.js";
import { formatTestReport, type TestReport } from "../plpgsql/test.js";

export function createPlxModuleTestTool({
  withClient,
  moduleRegistry,
  runTests,
}: {
  withClient: WithClient;
  moduleRegistry: Promise<ModuleRegistry>;
  runTests: (client: DbClient, testSchema: string, pattern?: string) => Promise<TestReport | null>;
}): ToolHandler {
  return {
    metadata: {
      name: "plx_test",
      description:
        "Run module tests for a PLX module.\n" +
        "Choose suite=unit or suite=integration. Uses the module public schema to resolve _ut/_it.\n" +
        "Injects a default test context: app.tenant_id='test' and inferred app.permissions for the module public schema.",
      schema: z.object({
        module: z.string().describe("Module name. Ex: quote"),
        suite: z.enum(["unit", "integration"]).optional().describe("Test suite. Default: unit."),
        pattern: z.string().optional().describe("Regex filter on test names. Ex: ^test_brand$"),
      }),
    },
    handler: async (args) => {
      const moduleName = args.module as string;
      const suite = (args.suite as "unit" | "integration" | undefined) ?? "unit";
      const pattern = args.pattern as string | undefined;
      const registry = await moduleRegistry;

      let testSchema: string;
      try {
        const manifest = await loadManifest(`${registry.workspaceRoot}/modules`, moduleName);
        if (!manifest.schemas.public) {
          return text(`problem: module '${moduleName}' has no public schema\nwhere: plx_test`);
        }
        testSchema = `${manifest.schemas.public}_${suite === "unit" ? "ut" : "it"}`;
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        return text(`problem: ${message}\nwhere: plx_test\nfix_hint: verify the module name`);
      }

      return await withClient(async (client) => {
        const report = await runTests(client, testSchema, pattern);
        if (!report) {
          return text(`problem: test schema '${testSchema}' not found or pgTAP not installed\nwhere: plx_test`);
        }
        return text(
          formatReadDocument({
            uri: `plx://module/${moduleName}/test/${suite}`,
            completeness: "full",
            body: [
              `module: ${moduleName}`,
              `suite: ${suite}`,
              `schema: ${testSchema}`,
              `context: tenant_id=test, permissions=inferred`,
              "",
              formatTestReport(report),
            ].join("\n"),
            next: [`plx_status module:${moduleName}`],
          }),
        );
      });
    },
  };
}
