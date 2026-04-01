import path from "node:path";
import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text, wrap } from "../../helpers.js";
import type { ModuleRegistry } from "../../pgm/registry.js";
import {
  diffModuleArtifacts,
  type PreparedModuleWorkflow,
  prepareModuleWorkflow,
  readAppliedArtifacts,
  sortApplyArtifacts,
} from "../../pgm/workflow.js";

export function createPgmModuleStatusTool({
  withClient,
  moduleRegistry,
}: {
  withClient: WithClient;
  moduleRegistry: Promise<ModuleRegistry>;
}): ToolHandler {
  return {
    metadata: {
      name: "pgm_module_status",
      description:
        "Inspect a PLX-first module for agent work.\n" +
        "Returns entrypoint, fragments, public contract, build freshness, and incremental apply state in LMNAV.",
      schema: z.object({
        module: z.string().describe("Module name. Ex: quote"),
      }),
    },
    handler: async (args) => {
      const moduleName = args.module as string;
      const registry = await moduleRegistry;

      let workflow: PreparedModuleWorkflow;
      try {
        workflow = await prepareModuleWorkflow(registry.workspaceRoot, moduleName);
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        return text(`problem: ${message}\nwhere: pgm_module_status\nfix_hint: verify the module name and plx.entry`);
      }

      let tracking = "unavailable";
      let applyStatus = "untracked";
      let changed: string[] = workflow.artifacts.map((artifact) => `${artifact.kind} ${artifact.name}`);
      let obsolete: string[] = [];
      let plan: string[] = [];
      let planProblem: string | undefined;
      try {
        plan = sortApplyArtifacts(workflow.artifacts).map((artifact) => `${artifact.kind} ${artifact.name}`);
      } catch (error: unknown) {
        planProblem = error instanceof Error ? error.message : String(error);
        applyStatus = "blocked";
      }
      try {
        const dbState = await withClient(async (client) => {
          return await readAppliedArtifacts(client, workflow.manifest.name);
        });
        if (dbState.available) {
          tracking = "available";
          const diff = diffModuleArtifacts(workflow.artifacts, dbState.states);
          changed = diff.changed.map((artifact) => `${artifact.kind} ${artifact.name}`);
          obsolete = diff.obsolete.map((artifact) => `${artifact.kind} ${artifact.name}`);
          try {
            plan = sortApplyArtifacts(diff.changed).map((artifact) => `${artifact.kind} ${artifact.name}`);
          } catch (error: unknown) {
            planProblem = error instanceof Error ? error.message : String(error);
          }
          applyStatus = planProblem
            ? "blocked"
            : obsolete.length > 0
              ? "drift"
              : changed.length > 0
                ? "stale"
                : "in_sync";
        }
      } catch {
        tracking = "error";
      }

      const contract = workflow.manifest.plxContract;
      const exports = contract?.exports.map((symbol) => `${symbol.schema}.${symbol.name}`) ?? [];
      const body: string[] = [];

      body.push(`module: ${workflow.manifest.name}`);
      body.push(`description: ${workflow.manifest.description}`);
      body.push(`path: ${rel(registry.workspaceRoot, workflow.moduleDir)}`);
      body.push(`entry: ${workflow.manifest.plx?.entry ?? "none"}`);
      body.push(`fragments: ${Math.max(0, workflow.prepared.files.length - 1)}`);
      body.push(`files: ${workflow.prepared.files.length}`);

      body.push("");
      body.push(
        `depends: ${workflow.manifest.dependencies.length > 0 ? workflow.manifest.dependencies.join(", ") : "none"}`,
      );
      if (exports.length > 0) {
        body.push("exports:");
        for (const item of exports) body.push(`  - ${item}`);
      } else {
        body.push("exports: none");
      }
      body.push(`internals: ${contract?.internals.length ?? 0}`);

      body.push("");
      body.push("build:");
      body.push(`  status: ${formatBuildStatus(workflow.buildFiles)}`);
      for (const file of workflow.buildFiles) {
        const target = file.file ?? "(no target)";
        body.push(`  ${file.kind}: ${target} ${file.status}`);
      }

      body.push("");
      body.push("apply:");
      body.push(`  tracking: ${tracking}`);
      body.push(`  status: ${applyStatus}`);
      body.push(`  changed: ${changed.length}`);
      if (changed.length > 0) {
        for (const item of changed.slice(0, 10)) body.push(`    - ${item}`);
        if (changed.length > 10) body.push(`    - ... +${changed.length - 10} more`);
      }
      body.push(`  obsolete: ${obsolete.length}`);
      if (obsolete.length > 0) {
        for (const item of obsolete.slice(0, 10)) body.push(`    - ${item}`);
        if (obsolete.length > 10) body.push(`    - ... +${obsolete.length - 10} more`);
      }
      if (planProblem) {
        body.push(`  plan_error: ${planProblem}`);
      } else if (plan.length > 0) {
        body.push("  plan:");
        for (const item of plan.slice(0, 10)) body.push(`    - ${item}`);
        if (plan.length > 10) body.push(`    - ... +${plan.length - 10} more`);
      }

      if (workflow.prepared.warnings.length > 0) {
        body.push("");
        body.push("warnings:");
        for (const warning of workflow.prepared.warnings.slice(0, 10)) body.push(`  - ${warning}`);
        if (workflow.prepared.warnings.length > 10) {
          body.push(`  - ... +${workflow.prepared.warnings.length - 10} more`);
        }
      } else {
        body.push("");
        body.push("warnings: none");
      }

      return text(
        wrap(`pgm://module/${workflow.manifest.name}`, "full", body.join("\n"), [
          `pgm_module_apply module:${workflow.manifest.name}`,
          `pgm_module_apply module:${workflow.manifest.name} apply:true`,
        ]),
      );
    },
  };
}

function rel(root: string, target: string): string {
  return path.relative(root, target).split(path.sep).join("/");
}

function formatBuildStatus(
  buildFiles: { status: "up_to_date" | "stale" | "missing" | "not_generated" | "unconfigured" }[],
): string {
  const relevant = buildFiles.filter((file) => file.status !== "not_generated");
  if (relevant.length === 0) return "not_generated";
  if (relevant.some((file) => file.status === "stale" || file.status === "missing" || file.status === "unconfigured")) {
    return "stale";
  }
  return "up_to_date";
}
