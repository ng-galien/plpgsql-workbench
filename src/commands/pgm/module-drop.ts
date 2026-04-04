import { z } from "zod";
import type { DbClient } from "../../core/connection.js";
import type { ToolHandler, WithClient } from "../../core/container.js";
import { text, wrap } from "../../core/helpers.js";
import type { ModuleRegistry } from "../../core/pgm/registry.js";
import { loadPlxManifest, plxSchemas } from "../../core/plx/manifest.js";

export function createPlxModuleDropTool({
  withClient,
  moduleRegistry,
}: {
  withClient: WithClient;
  moduleRegistry: Promise<ModuleRegistry>;
}): ToolHandler {
  return {
    metadata: {
      name: "plx_drop",
      description:
        "Drop a PLX module from the database.\n" +
        "Drops the module-owned schemas with CASCADE and clears apply tracking.\n" +
        "Dry-run by default. Set apply:true to execute.",
      schema: z.object({
        module: z.string().describe("Module name. Ex: quote"),
        apply: z.boolean().optional().describe("Actually execute the drop. Default: false (plan only)."),
      }),
    },
    handler: async (args) => {
      const moduleName = args.module as string;
      const apply = (args.apply as boolean | undefined) ?? false;
      const registry = await moduleRegistry;

      let schemas: string[];
      try {
        const manifest = await loadPlxManifest(`${registry.workspaceRoot}/modules`, moduleName);
        schemas = plxSchemas(manifest);
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        return text(`problem: ${message}\nwhere: plx_drop\nfix_hint: verify the module name`);
      }

      if (!apply) {
        return text(
          wrap(
            `plx://module/${moduleName}/drop`,
            "full",
            [
              `module: ${moduleName}`,
              "mode: dry-run",
              `schemas: ${schemas.length}`,
              "",
              "plan:",
              ...schemas.map((schema) => `  - drop schema ${schema} cascade`),
              "  - delete apply tracking",
            ].join("\n"),
            [`plx_drop module:${moduleName} apply:true`, `plx_status module:${moduleName}`],
          ),
        );
      }

      return await withClient(async (client) => {
        const result = await dropModuleSchemas(client, moduleName, schemas);
        return text(
          wrap(
            `plx://module/${moduleName}/drop`,
            "full",
            [
              `module: ${moduleName}`,
              "mode: drop",
              `ok: ${result.ok ? "true" : "false"}`,
              `transaction: ${result.transaction}`,
              `schemas_dropped: ${result.schemasDropped.length}`,
              "",
              ...(result.schemasDropped.length > 0
                ? ["results:", ...result.schemasDropped.map((schema) => `  - ${schema}`)]
                : []),
              ...(result.failure ? ["", `problem: ${result.failure.problem}`, `where: ${result.failure.where}`] : []),
            ].join("\n"),
            [`plx_status module:${moduleName}`],
          ),
        );
      });
    },
  };
}

function ownedSchemas(schemas: { public: string | null; private: string | null; qa?: string | null }): string[] {
  const values = new Set<string>();
  if (schemas.public) {
    values.add(schemas.public);
    values.add(`${schemas.public}_ut`);
    values.add(`${schemas.public}_it`);
    values.add(`${schemas.public}_qa`);
  }
  if (schemas.private) values.add(schemas.private);
  if (schemas.qa) values.add(schemas.qa);
  return [...values].sort();
}

async function dropModuleSchemas(
  client: DbClient,
  moduleName: string,
  schemas: string[],
): Promise<{
  ok: boolean;
  transaction: "committed" | "rolled_back";
  schemasDropped: string[];
  failure?: { problem: string; where: string };
}> {
  const qi = (id: string) => `"${id.replace(/"/g, '""')}"`;
  const dropped: string[] = [];

  await client.query("BEGIN");
  try {
    for (const schema of schemas) {
      await client.query(`DROP SCHEMA IF EXISTS ${qi(schema)} CASCADE`);
      dropped.push(schema);
    }
    try {
      await client.query(`DELETE FROM workbench.applied_module_artifact WHERE module_name = $1`, [moduleName]);
    } catch (error: unknown) {
      const code = (error as { code?: string }).code;
      if (code !== "42P01" && code !== "3F000") throw error;
    }
    await client.query("COMMIT");
    return { ok: true, transaction: "committed", schemasDropped: dropped };
  } catch (error: unknown) {
    await client.query("ROLLBACK").catch(() => {});
    return {
      ok: false,
      transaction: "rolled_back",
      schemasDropped: dropped,
      failure: {
        problem: error instanceof Error ? error.message : String(error),
        where: "plx_drop",
      },
    };
  }
}
