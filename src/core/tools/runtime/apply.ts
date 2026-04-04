import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text, wrap } from "../../helpers.js";
import {
  applyRuntimeIncremental,
  diffRuntimeArtifacts,
  type PreparedRuntimeWorkflow,
  prepareRuntimeWorkflow,
  readAppliedRuntimeArtifacts,
  sortRuntimeArtifacts,
} from "../../runtime/workflow.js";

export function createRuntimeApplyTool({
  withClient,
  workspaceRoot,
}: {
  withClient: WithClient;
  workspaceRoot: string;
}): ToolHandler {
  return {
    metadata: {
      name: "runtime_apply",
      description:
        "Plan or apply a runtime target from runtime/.\n" +
        "Applies build/*.ddl.sql, then src/*.sql, then tests/*.sql. Dry-run by default.",
      schema: z.object({
        target: z.string().describe("Runtime target. Ex: sdui"),
        apply: z.boolean().optional().describe("Actually execute the apply. Default: false."),
      }),
    },
    handler: async (args) => {
      const target = args.target as string;
      const apply = (args.apply as boolean | undefined) ?? false;

      let workflow: PreparedRuntimeWorkflow;
      try {
        workflow = await prepareRuntimeWorkflow(workspaceRoot, target);
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        return text(`problem: ${message}\nwhere: runtime_apply\nfix_hint: verify the runtime target name`);
      }

      if (!apply) {
        let tracking = "unavailable";
        let diff = {
          changed: workflow.artifacts,
          unchanged: [] as typeof workflow.artifacts,
          obsolete: [] as { kind: string; name: string }[],
        };
        try {
          const dbState = await withClient((client) => readAppliedRuntimeArtifacts(client, target));
          if (dbState.available) {
            tracking = "available";
            diff = diffRuntimeArtifacts(workflow.artifacts, dbState.states);
          }
        } catch {
          tracking = "error";
        }
        const plan = sortRuntimeArtifacts(diff.changed);
        const body: string[] = [];
        body.push(`target: ${target}`);
        body.push("mode: dry-run");
        body.push(`tracking: ${tracking}`);
        body.push(`changed: ${diff.changed.length}`);
        body.push(`unchanged: ${diff.unchanged.length}`);
        body.push(`obsolete: ${diff.obsolete.length}`);
        body.push("");
        body.push("plan:");
        if (plan.length === 0) body.push("  - no changes");
        else {
          for (const artifact of plan.slice(0, 30)) body.push(`  - apply ${artifact.kind} ${artifact.file}`);
          if (plan.length > 30) body.push(`  - ... +${plan.length - 30} more`);
        }
        return text(
          wrap(`runtime://${target}/apply`, "full", body.join("\n"), [
            `runtime_apply target:${target} apply:true`,
            `runtime_status target:${target}`,
          ]),
        );
      }

      return await withClient(async (client) => {
        const result = await applyRuntimeIncremental(client, workflow);
        const body: string[] = [];
        body.push(`target: ${target}`);
        body.push("mode: apply");
        body.push(`ok: ${result.ok ? "true" : "false"}`);
        body.push(`transaction: ${result.transaction}`);
        body.push(`applied: ${result.results.filter((item) => item.action === "applied").length}`);
        body.push(`unchanged: ${result.results.filter((item) => item.action === "unchanged").length}`);
        body.push(`obsolete: ${result.obsolete.length}`);
        body.push("");
        if (result.failure) {
          body.push(`problem: ${result.failure.problem}`);
          body.push(`failure_stage: ${result.failure.stage}`);
          body.push(`where: ${result.failure.where}`);
          if (result.failure.fixHint) body.push(`fix_hint: ${result.failure.fixHint}`);
        } else {
          body.push("results:");
          if (result.plan.length === 0) body.push("  - no changes");
          for (const artifact of result.plan) body.push(`  - applied ${artifact.kind} ${artifact.file}`);
        }
        if (result.warnings.length > 0) {
          body.push("");
          body.push("warnings:");
          for (const warning of result.warnings.slice(0, 20)) body.push(`  - ${warning}`);
        }
        return text(
          wrap(`runtime://${target}/apply`, "full", body.join("\n"), [
            `runtime_status target:${target}`,
            ...(result.ok ? [] : [`runtime_apply target:${target} apply:true`]),
          ]),
        );
      });
    },
  };
}
