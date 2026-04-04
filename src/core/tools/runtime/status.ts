import path from "node:path";
import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text, wrap } from "../../helpers.js";
import {
  diffRuntimeArtifacts,
  type PreparedRuntimeWorkflow,
  prepareRuntimeWorkflow,
  readAppliedRuntimeArtifacts,
  sortRuntimeArtifacts,
} from "../../runtime/workflow.js";

export function createRuntimeStatusTool({
  withClient,
  workspaceRoot,
}: {
  withClient: WithClient;
  workspaceRoot: string;
}): ToolHandler {
  return {
    metadata: {
      name: "runtime_status",
      description:
        "Inspect a runtime target under runtime/.\n" +
        "Returns files, build/apply freshness, and incremental apply state.",
      schema: z.object({
        target: z.string().describe("Runtime target. Ex: sdui"),
      }),
    },
    handler: async (args) => {
      const target = args.target as string;

      let workflow: PreparedRuntimeWorkflow;
      try {
        workflow = await prepareRuntimeWorkflow(workspaceRoot, target);
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        return text(`problem: ${message}\nwhere: runtime_status\nfix_hint: verify the runtime target name`);
      }

      let tracking = "unavailable";
      let applyStatus = "untracked";
      let changed = workflow.artifacts;
      let obsolete: { kind: string; name: string }[] = [];
      let plan: { kind: string; name: string }[] = [];
      try {
        plan = sortRuntimeArtifacts(changed).map((artifact) => ({ kind: artifact.kind, name: artifact.name }));
      } catch {
        applyStatus = "blocked";
      }

      try {
        const dbState = await withClient((client) => readAppliedRuntimeArtifacts(client, target));
        if (dbState.available) {
          tracking = "available";
          const diff = diffRuntimeArtifacts(workflow.artifacts, dbState.states);
          changed = diff.changed;
          obsolete = diff.obsolete;
          plan = sortRuntimeArtifacts(diff.changed).map((artifact) => ({ kind: artifact.kind, name: artifact.name }));
          applyStatus = obsolete.length > 0 ? "drift" : changed.length > 0 ? "stale" : "in_sync";
        }
      } catch {
        tracking = "error";
      }

      const body: string[] = [];
      body.push(`target: ${target}`);
      body.push(`path: ${rel(workspaceRoot, workflow.targetDir)}`);
      body.push("");
      body.push("files:");
      body.push(`  build: ${workflow.buildFiles.length}`);
      body.push(`  src: ${workflow.srcFiles.length}`);
      body.push(`  tests: ${workflow.testFiles.length}`);
      body.push(`  artifacts: ${workflow.artifacts.length}`);
      body.push("");
      body.push("apply:");
      body.push(`  tracking: ${tracking}`);
      body.push(`  status: ${applyStatus}`);
      body.push(`  changed: ${changed.length}`);
      body.push(`  obsolete: ${obsolete.length}`);
      if (plan.length > 0) {
        body.push("  plan:");
        for (const item of plan.slice(0, 20)) body.push(`    - ${item.kind} ${item.name}`);
        if (plan.length > 20) body.push(`    - ... +${plan.length - 20} more`);
      } else {
        body.push("  plan: none");
      }

      return text(
        wrap(`runtime://${target}`, "full", body.join("\n"), [
          `runtime_apply target:${target}`,
          `runtime_apply target:${target} apply:true`,
        ]),
      );
    },
  };
}

function rel(root: string, target: string): string {
  return path.relative(root, target).split(path.sep).join("/");
}
