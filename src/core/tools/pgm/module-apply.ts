import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text, wrap } from "../../helpers.js";
import type { ModuleRegistry } from "../../pgm/registry.js";
import {
  type AppliedArtifactState,
  applyModuleIncremental,
  diffModuleArtifacts,
  type ModuleWorkflowArtifact,
  type PreparedModuleWorkflow,
  prepareModuleWorkflow,
  readAppliedArtifacts,
  sortApplyArtifacts,
} from "../../pgm/workflow.js";

export function createPgmModuleApplyTool({
  withClient,
  moduleRegistry,
}: {
  withClient: WithClient;
  moduleRegistry: Promise<ModuleRegistry>;
}): ToolHandler {
  return {
    metadata: {
      name: "plx_apply",
      description:
        "Plan or apply a PLX-first module incrementally.\n" +
        "Builds the full module, then applies only changed artifacts (DDL, functions, generated test functions, grants/extensions).\n" +
        "Does not run module tests; use pg_test explicitly after apply.\n" +
        "Dry-run by default. Set apply:true to execute.",
      schema: z.object({
        module: z.string().describe("Module name. Ex: quote"),
        apply: z.boolean().optional().describe("Actually execute the incremental apply. Default: false (plan only)."),
        validate: z.boolean().optional().describe("Enable PG parser validation during PLX compile. Default: false."),
      }),
    },
    handler: async (args) => {
      const moduleName = args.module as string;
      const apply = (args.apply as boolean | undefined) ?? false;
      const validate = (args.validate as boolean | undefined) ?? false;
      const registry = await moduleRegistry;

      let workflow: PreparedModuleWorkflow;
      try {
        workflow = await prepareModuleWorkflow(registry.workspaceRoot, moduleName, { validate });
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        return text(`problem: ${message}\nwhere: plx_apply\nfix_hint: verify the module name and plx.entry`);
      }

      if (!apply) {
        let tracking = "unavailable";
        let diff: {
          changed: ModuleWorkflowArtifact[];
          unchanged: ModuleWorkflowArtifact[];
          obsolete: AppliedArtifactState[];
        } = {
          changed: workflow.artifacts,
          unchanged: [],
          obsolete: [],
        };
        try {
          const dbState = await withClient(async (client) => {
            return await readAppliedArtifacts(client, workflow.manifest.name);
          });
          if (dbState.available) {
            tracking = "available";
            diff = diffModuleArtifacts(workflow.artifacts, dbState.states);
          }
        } catch {
          tracking = "error";
        }
        try {
          const plan = sortApplyArtifacts(diff.changed);
          return text(formatApplyPlan(workflow.manifest.name, tracking, diff, plan));
        } catch (error: unknown) {
          const message = error instanceof Error ? error.message : String(error);
          return text(
            `problem: ${message}\nwhere: plx_apply.ordering\nfix_hint: break the artifact dependency cycle before applying the module`,
          );
        }
      }

      return await withClient(async (client) => {
        const result = await applyModuleIncremental(client, workflow);
        return text(formatApplyExecution(workflow.manifest.name, result));
      });
    },
  };
}

function formatApplyPlan(
  moduleName: string,
  tracking: string,
  diff: {
    changed: { kind: string; name: string }[];
    unchanged: { kind: string; name: string }[];
    obsolete: { kind: string; name: string }[];
  },
  plan: { kind: string; name: string }[],
): string {
  const body: string[] = [];
  body.push(`module: ${moduleName}`);
  body.push("mode: dry-run");
  body.push(`tracking: ${tracking}`);
  body.push(`changed: ${diff.changed.length}`);
  body.push(`unchanged: ${diff.unchanged.length}`);
  body.push(`obsolete: ${diff.obsolete.length}`);
  body.push("");
  body.push("plan:");
  if (plan.length === 0) {
    body.push("  - no changes");
  } else {
    for (const artifact of plan.slice(0, 20)) body.push(`  - apply ${artifact.kind} ${artifact.name}`);
    if (plan.length > 20) body.push(`  - ... +${plan.length - 20} more`);
  }
  if (diff.obsolete.length > 0) {
    body.push("");
    body.push("warnings:");
    for (const artifact of diff.obsolete.slice(0, 20)) {
      body.push(`  - obsolete tracked artifact: ${artifact.kind} ${artifact.name}`);
    }
    if (diff.obsolete.length > 20) body.push(`  - ... +${diff.obsolete.length - 20} more`);
  }

  return wrap(`plx://module/${moduleName}/apply`, "full", body.join("\n"), [
    `plx_apply module:${moduleName} apply:true`,
    `plx_status module:${moduleName}`,
  ]);
}

function formatApplyExecution(
  moduleName: string,
  result: {
    ok: boolean;
    transaction: "not_started" | "committed" | "rolled_back";
    diff: { changed: { kind: string; name: string }[]; unchanged: { kind: string; name: string }[] };
    plan: { kind: string; name: string }[];
    results: { action: "applied" | "unchanged"; kind: string; name: string; warning?: string }[];
    warnings: string[];
    obsolete: { kind: string; name: string }[];
    buildFiles: string[];
    postActions: string[];
    failure?: { problem: string; stage: string; where: string; fixHint?: string };
  },
): string {
  const body: string[] = [];
  body.push(`module: ${moduleName}`);
  body.push("mode: apply");
  body.push(`ok: ${result.ok ? "true" : "false"}`);
  body.push(`transaction: ${result.transaction}`);
  body.push(`applied: ${result.results.filter((item) => item.action === "applied").length}`);
  body.push(`unchanged: ${result.results.filter((item) => item.action === "unchanged").length}`);
  body.push(`obsolete: ${result.obsolete.length}`);
  body.push(`build_files: ${result.buildFiles.length}`);
  body.push("");

  if (result.buildFiles.length > 0) {
    body.push("build:");
    for (const file of result.buildFiles) body.push(`  - ${file}`);
    body.push("");
  }

  if (result.failure) {
    body.push(`problem: ${result.failure.problem}`);
    body.push(`failure_stage: ${result.failure.stage}`);
    body.push(`where: ${result.failure.where}`);
    if (result.failure.fixHint) body.push(`fix_hint: ${result.failure.fixHint}`);
  } else {
    body.push("results:");
    for (const item of result.plan) {
      const applied = result.results.find(
        (entry) => entry.action === "applied" && entry.kind === item.kind && entry.name === item.name,
      );
      if (!applied) continue;
      body.push(`  - applied ${item.kind} ${item.name}`);
      if (applied.warning) body.push(`    warning: ${applied.warning}`);
    }
    if (result.results.every((entry) => entry.action !== "applied")) {
      body.push("  - no changes");
    }
  }

  if (result.warnings.length > 0) {
    body.push("");
    body.push("warnings:");
    for (const warning of result.warnings.slice(0, 20)) body.push(`  - ${warning}`);
    if (result.warnings.length > 20) body.push(`  - ... +${result.warnings.length - 20} more`);
  }

  if (result.postActions.length > 0) {
    body.push("");
    body.push("post_apply:");
    for (const action of result.postActions) body.push(`  - ${action}`);
  }

  return wrap(`plx://module/${moduleName}/apply`, "full", body.join("\n"), [
    `plx_status module:${moduleName}`,
    ...(result.ok ? [] : [`plx_apply module:${moduleName} apply:true`]),
  ]);
}
