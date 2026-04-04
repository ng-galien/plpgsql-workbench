import { asFunction } from "awilix";
import type { Plugin } from "../core/plugin.js";
import { createOpenTool } from "../integrations/docstore/open.js";
import { createPeekTool } from "../integrations/docstore/peek.js";
import { createScanTool } from "../integrations/docstore/scan.js";
import { createSyncTool } from "../integrations/docstore/sync.js";

export const docstorePlugin: Plugin = {
  id: "docstore",
  name: "Docstore",
  requires: ["withClient"],

  register(container) {
    container.register({
      scanTool: asFunction(createScanTool).singleton(),
      syncTool: asFunction(createSyncTool).singleton(),
      peekTool: asFunction(createPeekTool).singleton(),
      openTool: asFunction(createOpenTool).singleton(),
    });
  },
};
