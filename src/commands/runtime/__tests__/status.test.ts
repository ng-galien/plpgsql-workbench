import { afterEach, describe, expect, it, vi } from "vitest";

const mockPrepareRuntimeWorkflow = vi.fn();
const mockSortRuntimeArtifacts = vi.fn((artifacts) => artifacts);

vi.mock("../../../core/runtime/workflow.js", () => ({
  prepareRuntimeWorkflow: mockPrepareRuntimeWorkflow,
  sortRuntimeArtifacts: mockSortRuntimeArtifacts,
  diffRuntimeArtifacts: vi.fn(),
}));

afterEach(() => {
  vi.resetModules();
  vi.clearAllMocks();
});

describe("runtime_status tool", () => {
  it("renders status using shared read and applied-artifact primitives", async () => {
    mockPrepareRuntimeWorkflow.mockResolvedValue({
      workspaceRoot: "/workspace",
      runtimeDir: "/workspace/runtime",
      targetDir: "/workspace/runtime/sdui",
      target: "sdui",
      artifacts: [
        {
          key: "ddl:build/sdui.ddl.sql",
          kind: "ddl",
          name: "sdui",
          file: "build/sdui.ddl.sql",
          content: "CREATE SCHEMA sdui;",
          hash: "same",
        },
        {
          key: "sql:src/api.sql",
          kind: "sql",
          name: "api",
          file: "src/api.sql",
          content: "SELECT 1;",
          hash: "new",
        },
      ],
      buildFiles: ["build/sdui.ddl.sql"],
      srcFiles: ["src/api.sql"],
      testFiles: [],
    });

    const { createRuntimeStatusTool } = await import("../status.js");
    const tool = createRuntimeStatusTool({
      workspaceRoot: "/workspace",
      withClient: async (work) =>
        await work({
          query: vi.fn(async (sql: string) => {
            if (sql.includes("SELECT artifact_key")) {
              return {
                rows: [
                  {
                    artifact_key: "ddl:build/sdui.ddl.sql",
                    artifact_kind: "ddl",
                    artifact_name: "sdui",
                    artifact_hash: "same",
                    artifact_file: "build/sdui.ddl.sql",
                    applied_at: "2026-04-04 00:00:00+00",
                  },
                ],
                rowCount: 1,
              };
            }
            return { rows: [], rowCount: 0 };
          }),
        } as never),
    });

    const result = await tool.handler({ target: "sdui" }, {} as never);
    const output = result.content[0]?.text ?? "";

    expect(output).toContain("uri: runtime://sdui");
    expect(output).toContain("tracking: available");
    expect(output).toContain("status: stale");
    expect(output).toContain("next:");
    expect(output).toContain("runtime_apply target:sdui");
  });
});
