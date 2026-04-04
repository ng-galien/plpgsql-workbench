import { asFunction, asValue } from "awilix";
import { createPgmModuleApplyTool } from "../commands/pgm/module-apply.js";
import { createPlxModuleDropTool } from "../commands/pgm/module-drop.js";
import { createPgmModuleStatusTool } from "../commands/pgm/module-status.js";
import { createPlxModuleTestTool } from "../commands/pgm/module-test.js";
import { createPackTool } from "../commands/plpgsql/pack.js";
import { buildModuleRegistry } from "../core/pgm/registry.js";
import type { Plugin } from "../core/plugin.js";
import { resolveWorkspaceRoot } from "../core/workspace.js";

export const pgModulesPlugin: Plugin = {
  id: "pg-modules",
  name: "PLX Module Management",
  requires: ["withClient"],

  register(container) {
    const root = resolveWorkspaceRoot();
    container.register({
      moduleRegistry: asValue(buildModuleRegistry(root)),
      workspaceRoot: asValue(root),

      packTool: asFunction(createPackTool).singleton(),
      pgmModuleStatusTool: asFunction(createPgmModuleStatusTool).singleton(),
      pgmModuleApplyTool: asFunction(createPgmModuleApplyTool).singleton(),
      plxModuleDropTool: asFunction(createPlxModuleDropTool).singleton(),
      plxModuleTestTool: asFunction(createPlxModuleTestTool).singleton(),
    });
  },
};
