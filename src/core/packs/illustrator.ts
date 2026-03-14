/**
 * illustrator pack — DSL agent for visual document composition.
 *
 * 15 consolidated MCP tools (from 38 original).
 * Stores elements in document.canvas + document.element (PostgreSQL).
 */

import { asFunction, type AwilixContainer } from "awilix";
import type { ToolPack } from "../container.js";

// Consolidated tools
import { createIllDocTool } from "../tools/illustrator/ill-doc.js";
import { createIllAddTool } from "../tools/illustrator/ill-add.js";
import { createIllUpdateTool, createIllDeleteTool, createIllBatchTool } from "../tools/illustrator/ill-update.js";
import { createIllGroupTool } from "../tools/illustrator/ill-group.js";
import { createIllLayoutTool } from "../tools/illustrator/ill-layout.js";

// Kept as-is (read-only / unique behavior)
import { createGetStateTool } from "../tools/illustrator/get-state.js";
import { createUpdateMetaTool, createListAssetsTool, createShowMessageTool, createExportSvgTool, createCheckLayoutTool, createMeasureTextTool } from "../tools/illustrator/meta-assets.js";
import { createInspectStoreTool, createDispatchEventTool, createGetEventLogTool } from "../tools/illustrator/collaboration.js";

export const illustratorPack: ToolPack = (container: AwilixContainer, _config: Record<string, unknown>) => {
  container.register({
    // --- Consolidated (5 tools replace 26) ---
    illDocTool: asFunction(createIllDocTool).singleton(),           // new/list/load/delete/duplicate/rename/setup/clear
    illAddTool: asFunction(createIllAddTool).singleton(),           // text/rect/line/image/circle/ellipse/path
    illUpdateTool: asFunction(createIllUpdateTool).singleton(),     // single or batch update
    illDeleteTool: asFunction(createIllDeleteTool).singleton(),     // single or batch delete
    illBatchTool: asFunction(createIllBatchTool).singleton(),       // mixed add/update/delete ops
    illGroupTool: asFunction(createIllGroupTool).singleton(),       // create/dissolve/add/remove
    illLayoutTool: asFunction(createIllLayoutTool).singleton(),     // align/distribute/reorder/duplicate/move

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
