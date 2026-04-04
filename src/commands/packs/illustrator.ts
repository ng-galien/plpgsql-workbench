/**
 * illustrator pack — DSL agent for visual document composition.
 *
 * 15 consolidated MCP tools (from 38 original).
 * Stores elements in document.canvas + document.element (PostgreSQL).
 */

import { type AwilixContainer, asFunction } from "awilix";
import type { ToolPack } from "../../core/container.js";
import {
  createDispatchEventTool,
  createGetEventLogTool,
  createInspectStoreTool,
} from "../../integrations/illustrator/collaboration.js";
// Kept as-is (read-only / unique behavior)
import { createGetStateTool } from "../../integrations/illustrator/get-state.js";
import { createIllAddTool } from "../../integrations/illustrator/ill-add.js";
// Consolidated tools
import { createIllDocTool } from "../../integrations/illustrator/ill-doc.js";
import { createIllGroupTool } from "../../integrations/illustrator/ill-group.js";
import { createIllLayoutTool } from "../../integrations/illustrator/ill-layout.js";
import {
  createIllBatchTool,
  createIllDeleteTool,
  createIllUpdateTool,
} from "../../integrations/illustrator/ill-update.js";
import {
  createCheckLayoutTool,
  createExportSvgTool,
  createListAssetsTool,
  createMeasureTextTool,
  createShowMessageTool,
  createUpdateMetaTool,
} from "../../integrations/illustrator/meta-assets.js";

export const illustratorPack: ToolPack = (container: AwilixContainer, _config: Record<string, unknown>) => {
  container.register({
    // --- Consolidated (5 tools replace 26) ---
    illDocTool: asFunction(createIllDocTool).singleton(), // new/list/load/delete/duplicate/rename/setup/clear
    illAddTool: asFunction(createIllAddTool).singleton(), // text/rect/line/image/circle/ellipse/path
    illUpdateTool: asFunction(createIllUpdateTool).singleton(), // single or batch update
    illDeleteTool: asFunction(createIllDeleteTool).singleton(), // single or batch delete
    illBatchTool: asFunction(createIllBatchTool).singleton(), // mixed add/update/delete ops
    illGroupTool: asFunction(createIllGroupTool).singleton(), // create/dissolve/add/remove
    illLayoutTool: asFunction(createIllLayoutTool).singleton(), // align/distribute/reorder/duplicate/move

    // --- Kept as-is (8 tools) ---
    illGetStateTool: asFunction(createGetStateTool).singleton(),
    illMeasureTextTool: asFunction(createMeasureTextTool).singleton(),
    illCheckLayoutTool: asFunction(createCheckLayoutTool).singleton(),
    illUpdateMetaTool: asFunction(createUpdateMetaTool).singleton(),
    illListAssetsTool: asFunction(createListAssetsTool).singleton(),
    illExportSvgTool: asFunction(createExportSvgTool).singleton(),
    illShowMessageTool: asFunction(createShowMessageTool).singleton(),

    // --- Collaboration (3 tools) ---
    illInspectStoreTool: asFunction(createInspectStoreTool).singleton(),
    illDispatchEventTool: asFunction(createDispatchEventTool).singleton(),
    illGetEventLogTool: asFunction(createGetEventLogTool).singleton(),
  });
};
