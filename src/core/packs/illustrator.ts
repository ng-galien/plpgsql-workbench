/**
 * illustrator pack — DSL agent for visual document composition.
 *
 * Registers illustrator tools into the Awilix container.
 * Depends on `withClient` being already registered (by plpgsql pack or edge driver).
 * Tools call document.* PG functions for storage, with TypeScript logic
 * for positioning, font measurement, layout analysis, and export.
 */

import { asFunction, type AwilixContainer } from "awilix";
import type { ToolPack } from "../container.js";

// Tool factories
import { createDocNewTool } from "../tools/illustrator/doc-new.js";
import { createGetStateTool } from "../tools/illustrator/get-state.js";
import { createAddTextTool, createAddRectTool, createAddLineTool } from "../tools/illustrator/add-element.js";

export const illustratorPack: ToolPack = (container: AwilixContainer, _config: Record<string, unknown>) => {
  container.register({
    // --- Illustrator tools (Phase 1: core set) ---
    illDocNewTool: asFunction(createDocNewTool).singleton(),
    illGetStateTool: asFunction(createGetStateTool).singleton(),
    illAddTextTool: asFunction(createAddTextTool).singleton(),
    illAddRectTool: asFunction(createAddRectTool).singleton(),
    illAddLineTool: asFunction(createAddLineTool).singleton(),
  });
};
