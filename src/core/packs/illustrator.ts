/**
 * illustrator pack — DSL agent for visual document composition.
 *
 * 38 MCP tools for creating, editing, and exporting visual documents.
 * Stores elements in document.canvas + document.element (PostgreSQL).
 * TypeScript handles positioning, font measurement, layout analysis, and export.
 */

import { asFunction, type AwilixContainer } from "awilix";
import type { ToolPack } from "../container.js";

// Document CRUD
import { createDocNewTool } from "../tools/illustrator/doc-new.js";
import { createDocListTool, createDocLoadTool, createDocDeleteTool, createDocDuplicateTool, createDocRenameTool, createDocSaveTool, createCanvasSetupTool } from "../tools/illustrator/doc-crud.js";

// Element creation
import { createAddTextTool, createAddRectTool, createAddLineTool } from "../tools/illustrator/add-element.js";
import { createAddImageTool } from "../tools/illustrator/add-image.js";

// Element mutation
import { createUpdateElementTool, createDeleteElementTool, createElementDuplicateTool, createReorderElementTool, createClearCanvasTool, createBatchUpdateTool, createBatchAddTool } from "../tools/illustrator/element-mutate.js";

// Groups
import { createGroupElementsTool, createUngroupTool, createAddToGroupTool, createRemoveFromGroupTool } from "../tools/illustrator/groups.js";

// Align + Distribute
import { createAlignTool, createDistributeTool } from "../tools/illustrator/align-distribute.js";

// State
import { createGetStateTool } from "../tools/illustrator/get-state.js";

// Meta, Assets, Export, Layout
import { createUpdateMetaTool, createListAssetsTool, createShowMessageTool, createExportSvgTool, createCheckLayoutTool, createMeasureTextTool } from "../tools/illustrator/meta-assets.js";

export const illustratorPack: ToolPack = (container: AwilixContainer, _config: Record<string, unknown>) => {
  container.register({
    // --- Document CRUD (8 tools) ---
    illDocNewTool: asFunction(createDocNewTool).singleton(),
    illDocListTool: asFunction(createDocListTool).singleton(),
    illDocLoadTool: asFunction(createDocLoadTool).singleton(),
    illDocDeleteTool: asFunction(createDocDeleteTool).singleton(),
    illDocDuplicateTool: asFunction(createDocDuplicateTool).singleton(),
    illDocRenameTool: asFunction(createDocRenameTool).singleton(),
    illDocSaveTool: asFunction(createDocSaveTool).singleton(),
    illCanvasSetupTool: asFunction(createCanvasSetupTool).singleton(),

    // --- Element creation (4 tools) ---
    illAddTextTool: asFunction(createAddTextTool).singleton(),
    illAddRectTool: asFunction(createAddRectTool).singleton(),
    illAddLineTool: asFunction(createAddLineTool).singleton(),
    illAddImageTool: asFunction(createAddImageTool).singleton(),

    // --- Element mutation (7 tools) ---
    illUpdateElementTool: asFunction(createUpdateElementTool).singleton(),
    illDeleteElementTool: asFunction(createDeleteElementTool).singleton(),
    illElementDuplicateTool: asFunction(createElementDuplicateTool).singleton(),
    illReorderElementTool: asFunction(createReorderElementTool).singleton(),
    illClearCanvasTool: asFunction(createClearCanvasTool).singleton(),
    illBatchUpdateTool: asFunction(createBatchUpdateTool).singleton(),
    illBatchAddTool: asFunction(createBatchAddTool).singleton(),

    // --- Groups (4 tools) ---
    illGroupElementsTool: asFunction(createGroupElementsTool).singleton(),
    illUngroupTool: asFunction(createUngroupTool).singleton(),
    illAddToGroupTool: asFunction(createAddToGroupTool).singleton(),
    illRemoveFromGroupTool: asFunction(createRemoveFromGroupTool).singleton(),

    // --- Align + Distribute (2 tools) ---
    illAlignTool: asFunction(createAlignTool).singleton(),
    illDistributeTool: asFunction(createDistributeTool).singleton(),

    // --- State + Inspection (3 tools) ---
    illGetStateTool: asFunction(createGetStateTool).singleton(),
    illMeasureTextTool: asFunction(createMeasureTextTool).singleton(),
    illCheckLayoutTool: asFunction(createCheckLayoutTool).singleton(),

    // --- Meta + Assets (2 tools) ---
    illUpdateMetaTool: asFunction(createUpdateMetaTool).singleton(),
    illListAssetsTool: asFunction(createListAssetsTool).singleton(),

    // --- Export (1 tool) ---
    illExportSvgTool: asFunction(createExportSvgTool).singleton(),

    // --- Communication (1 tool) ---
    illShowMessageTool: asFunction(createShowMessageTool).singleton(),

    // --- TODO: Phase 2 ---
    // illSnapshotTool (resvg PNG)
    // illExportPdfTool (pdf-lib)
    // illInspectStoreTool (Supabase Realtime)
    // illDispatchEventTool (Supabase Realtime)
    // illGetEventLogTool (Supabase Realtime)
  });
};
