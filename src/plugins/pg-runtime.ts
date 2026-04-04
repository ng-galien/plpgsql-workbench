import { asFunction } from "awilix";
import { createRuntimeApplyTool } from "../commands/runtime/apply.js";
import { createRuntimeStatusTool } from "../commands/runtime/status.js";
import { createRuntimeTestTool } from "../commands/runtime/test.js";
import type { Plugin } from "../core/plugin.js";

export const pgRuntimePlugin: Plugin = {
  id: "pg-runtime",
  name: "Runtime Platform",
  requires: ["withClient", "workspaceRoot"],

  register(container) {
    container.register({
      runtimeStatusTool: asFunction(createRuntimeStatusTool).singleton(),
      runtimeApplyTool: asFunction(createRuntimeApplyTool).singleton(),
      runtimeTestTool: asFunction(createRuntimeTestTool).singleton(),
    });
  },
};
