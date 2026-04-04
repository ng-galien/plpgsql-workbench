/**
 * docstore pack — file reference management.
 *
 * Registers scan, sync, peek, and open tools for tracking and reading
 * filesystem files with PostgreSQL as the index store.
 * Depends on pool/withClient being registered by another pack (e.g. plpgsql).
 */

import { type AwilixContainer, asFunction } from "awilix";
import type { ToolPack } from "../../core/container.js";
import { createOpenTool } from "../../integrations/docstore/open.js";
import { createPeekTool } from "../../integrations/docstore/peek.js";
import { createScanTool } from "../../integrations/docstore/scan.js";
import { createSyncTool } from "../../integrations/docstore/sync.js";

export const docstorePack: ToolPack = (container: AwilixContainer, _config: Record<string, unknown>) => {
  // Validate that withClient is available (registered by plpgsql or another pack)
  if (!container.registrations.withClient) {
    throw new Error("docstore pack requires withClient — load the plpgsql pack first");
  }

  container.register({
    scanTool: asFunction(createScanTool).singleton(),
    syncTool: asFunction(createSyncTool).singleton(),
    peekTool: asFunction(createPeekTool).singleton(),
    openTool: asFunction(createOpenTool).singleton(),
  });
};
