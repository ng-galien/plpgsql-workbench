import { asFunction } from "awilix";
import { createHealthTool } from "../commands/plpgsql/health.js";
import { createPreviewTool } from "../commands/plpgsql/preview.js";
import { createVisualTool } from "../commands/plpgsql/visual.js";
import type { Plugin } from "../core/plugin.js";

export const pgOperationsPlugin: Plugin = {
  id: "pg-operations",
  name: "Workspace Operations",
  requires: ["withClient"],

  register(container) {
    container.register({
      healthTool: asFunction(createHealthTool).singleton(),
      previewTool: asFunction(createPreviewTool).singleton(),
      visualTool: asFunction(createVisualTool).singleton(),
    });
  },
};
