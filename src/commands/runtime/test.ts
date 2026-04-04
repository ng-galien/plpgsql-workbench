import { z } from "zod";
import type { DbClient } from "../../core/connection.js";
import type { ToolHandler, WithClient } from "../../core/container.js";
import { text } from "../../core/helpers.js";
import { type PreparedRuntimeWorkflow, prepareRuntimeWorkflow } from "../../core/runtime/workflow.js";
import { formatReadDocument } from "../../core/tooling/primitives/read.js";
import { formatTestReport, type TestReport } from "../plpgsql/test.js";

export function createRuntimeTestTool({
  withClient,
  workspaceRoot,
  runTests,
}: {
  withClient: WithClient;
  workspaceRoot: string;
  runTests: (client: DbClient, testSchema: string, pattern?: string) => Promise<TestReport | null>;
}): ToolHandler {
  return {
    metadata: {
      name: "runtime_test",
      description: "Run pgTAP tests for a runtime target.\n" + "Uses <target>_ut by convention when tests/*.sql exist.",
      schema: z.object({
        target: z.string().describe("Runtime target. Ex: sdui"),
        pattern: z.string().optional().describe("Regex filter on test names. Ex: ^test_api$"),
      }),
    },
    handler: async (args) => {
      const target = args.target as string;
      const pattern = args.pattern as string | undefined;

      let workflow: PreparedRuntimeWorkflow;
      try {
        workflow = await prepareRuntimeWorkflow(workspaceRoot, target);
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        return text(`problem: ${message}\nwhere: runtime_test\nfix_hint: verify the runtime target name`);
      }

      if (workflow.testFiles.length === 0) {
        return text(`problem: runtime target '${target}' has no tests\nwhere: runtime_test`);
      }

      const testSchema = `${target}_ut`;
      return await withClient(async (client) => {
        const report = await runTests(client, testSchema, pattern);
        if (!report) {
          return text(`problem: test schema '${testSchema}' not found or pgTAP not installed\nwhere: runtime_test`);
        }
        return text(
          formatReadDocument({
            uri: `runtime://${target}/test`,
            completeness: "full",
            body: [`target: ${target}`, `schema: ${testSchema}`, "", formatTestReport(report)].join("\n"),
            next: [`runtime_status target:${target}`],
          }),
        );
      });
    },
  };
}
