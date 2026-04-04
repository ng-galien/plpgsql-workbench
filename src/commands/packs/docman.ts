/**
 * docman pack — Document Manager application.
 *
 * Business layer on top of platform primitives (fs_*, gmail_*).
 * Tools call docman.* PL/pgSQL functions — zero inline SQL.
 *
 * Configuration is read from workbench.config (app='docman') at request time.
 * Keys: documentsRoot
 */

import { type AwilixContainer, asFunction } from "awilix";
import type { ToolPack } from "../../core/container.js";
import { createDocClassifyTool } from "../../integrations/docman/classify.js";
import { createDocFetchMailTool } from "../../integrations/docman/fetch-mail.js";
import { createDocImportTool } from "../../integrations/docman/import.js";
import { createDocInboxTool } from "../../integrations/docman/inbox.js";
import {
  createDocDocTypesTool,
  createDocEntitiesTool,
  createDocEntityKindsTool,
  createDocLabelsTool,
} from "../../integrations/docman/labels.js";
import { createDocLinkTool, createDocUnlinkTool } from "../../integrations/docman/link.js";
import { createDocPeekTool } from "../../integrations/docman/peek.js";
import {
  createDocRelateTool,
  createDocRelationsTool,
  createDocUnrelateTool,
} from "../../integrations/docman/relate.js";
import { createDocSearchTool } from "../../integrations/docman/search.js";
import { createDocTagTool, createDocUntagTool } from "../../integrations/docman/tag.js";

export const docmanPack: ToolPack = (container: AwilixContainer) => {
  container.register({
    // Orchestrators
    docImportTool: asFunction(createDocImportTool).singleton(),
    docPeekTool: asFunction(createDocPeekTool).singleton(),

    // Classification
    docClassifyTool: asFunction(createDocClassifyTool).singleton(),
    docTagTool: asFunction(createDocTagTool).singleton(),
    docUntagTool: asFunction(createDocUntagTool).singleton(),
    docLinkTool: asFunction(createDocLinkTool).singleton(),
    docUnlinkTool: asFunction(createDocUnlinkTool).singleton(),
    docRelateTool: asFunction(createDocRelateTool).singleton(),
    docUnrelateTool: asFunction(createDocUnrelateTool).singleton(),

    // Consultation
    docInboxTool: asFunction(createDocInboxTool).singleton(),
    docSearchTool: asFunction(createDocSearchTool).singleton(),
    docLabelsTool: asFunction(createDocLabelsTool).singleton(),
    docEntitiesTool: asFunction(createDocEntitiesTool).singleton(),
    docEntityKindsTool: asFunction(createDocEntityKindsTool).singleton(),
    docDocTypesTool: asFunction(createDocDocTypesTool).singleton(),
    docRelationsTool: asFunction(createDocRelationsTool).singleton(),
  });

  // doc_fetch_mail requires gmail primitives (google pack)
  if (
    container.hasRegistration("gmailSearchTool") &&
    container.hasRegistration("gmailAttachmentTool") &&
    container.hasRegistration("gmailReadTool")
  ) {
    container.register({
      docFetchMailTool: asFunction(createDocFetchMailTool).singleton(),
    });
  }
};
