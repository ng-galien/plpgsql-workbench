import { asFunction } from "awilix";
import type { Plugin } from "../core/plugin.js";
import {
  createDispatchEventTool,
  createGetEventLogTool,
  createInspectStoreTool,
} from "../integrations/illustrator/collaboration.js";
import { createGetStateTool } from "../integrations/illustrator/get-state.js";
import { createIllAddTool } from "../integrations/illustrator/ill-add.js";
import { createIllDocTool } from "../integrations/illustrator/ill-doc.js";
import { createIllGroupTool } from "../integrations/illustrator/ill-group.js";
import { createIllLayoutTool } from "../integrations/illustrator/ill-layout.js";
import {
  createIllBatchTool,
  createIllDeleteTool,
  createIllUpdateTool,
} from "../integrations/illustrator/ill-update.js";
import {
  createCheckLayoutTool,
  createExportSvgTool,
  createListAssetsTool,
  createMeasureTextTool,
  createShowMessageTool,
  createUpdateMetaTool,
} from "../integrations/illustrator/meta-assets.js";

export const illustratorPlugin: Plugin = {
  id: "illustrator",
  name: "Visual Document Composition",
  requires: ["withClient"],

  register(container) {
    container.register({
      illDocTool: asFunction(createIllDocTool).singleton(),
      illAddTool: asFunction(createIllAddTool).singleton(),
      illUpdateTool: asFunction(createIllUpdateTool).singleton(),
      illDeleteTool: asFunction(createIllDeleteTool).singleton(),
      illBatchTool: asFunction(createIllBatchTool).singleton(),
      illGroupTool: asFunction(createIllGroupTool).singleton(),
      illLayoutTool: asFunction(createIllLayoutTool).singleton(),
      illGetStateTool: asFunction(createGetStateTool).singleton(),
      illMeasureTextTool: asFunction(createMeasureTextTool).singleton(),
      illCheckLayoutTool: asFunction(createCheckLayoutTool).singleton(),
      illUpdateMetaTool: asFunction(createUpdateMetaTool).singleton(),
      illListAssetsTool: asFunction(createListAssetsTool).singleton(),
      illExportSvgTool: asFunction(createExportSvgTool).singleton(),
      illShowMessageTool: asFunction(createShowMessageTool).singleton(),
      illInspectStoreTool: asFunction(createInspectStoreTool).singleton(),
      illDispatchEventTool: asFunction(createDispatchEventTool).singleton(),
      illGetEventLogTool: asFunction(createGetEventLogTool).singleton(),
    });
  },
};
