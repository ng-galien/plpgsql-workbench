import { asFunction } from "awilix";
import type { Plugin } from "../core/plugin.js";
import { createDocClassifyTool } from "../integrations/docman/classify.js";
import { createDocFetchMailTool } from "../integrations/docman/fetch-mail.js";
import { createDocImportTool } from "../integrations/docman/import.js";
import { createDocInboxTool } from "../integrations/docman/inbox.js";
import {
  createDocDocTypesTool,
  createDocEntitiesTool,
  createDocEntityKindsTool,
  createDocLabelsTool,
} from "../integrations/docman/labels.js";
import { createDocLinkTool, createDocUnlinkTool } from "../integrations/docman/link.js";
import { createDocPeekTool } from "../integrations/docman/peek.js";
import { createDocRelateTool, createDocRelationsTool, createDocUnrelateTool } from "../integrations/docman/relate.js";
import { createDocSearchTool } from "../integrations/docman/search.js";
import { createDocTagTool, createDocUntagTool } from "../integrations/docman/tag.js";

export const docmanPlugin: Plugin = {
  id: "docman",
  name: "Document Manager",
  requires: ["withClient"],

  register(container) {
    container.register({
      docImportTool: asFunction(createDocImportTool).singleton(),
      docPeekTool: asFunction(createDocPeekTool).singleton(),
      docClassifyTool: asFunction(createDocClassifyTool).singleton(),
      docTagTool: asFunction(createDocTagTool).singleton(),
      docUntagTool: asFunction(createDocUntagTool).singleton(),
      docLinkTool: asFunction(createDocLinkTool).singleton(),
      docUnlinkTool: asFunction(createDocUnlinkTool).singleton(),
      docRelateTool: asFunction(createDocRelateTool).singleton(),
      docUnrelateTool: asFunction(createDocUnrelateTool).singleton(),
      docInboxTool: asFunction(createDocInboxTool).singleton(),
      docSearchTool: asFunction(createDocSearchTool).singleton(),
      docLabelsTool: asFunction(createDocLabelsTool).singleton(),
      docEntitiesTool: asFunction(createDocEntitiesTool).singleton(),
      docEntityKindsTool: asFunction(createDocEntityKindsTool).singleton(),
      docDocTypesTool: asFunction(createDocDocTypesTool).singleton(),
      docRelationsTool: asFunction(createDocRelationsTool).singleton(),
    });

    // doc_fetch_mail requires gmail capability
    const capabilities: Set<string> = container.hasRegistration("pluginCapabilities")
      ? container.resolve("pluginCapabilities")
      : new Set();
    if (capabilities.has("gmail")) {
      container.register({
        docFetchMailTool: asFunction(createDocFetchMailTool).singleton(),
      });
    }
  },
};
