/**
 * docman pack — Document Manager application.
 *
 * Business layer on top of platform primitives (fs_*, gmail_*).
 * Tools call docman.* PL/pgSQL functions — zero inline SQL.
 *
 * Configuration is read from workbench.config (app='docman') at request time.
 * Keys: documentsRoot
 */

import { asFunction, type AwilixContainer } from "awilix";
import type { ToolPack } from "../container.js";

import { createDocImportTool } from "../tools/docman/import.js";
import { createDocFetchMailTool } from "../tools/docman/fetch-mail.js";
import { createDocPeekTool } from "../tools/docman/peek.js";
import { createDocInboxTool } from "../tools/docman/inbox.js";
import { createDocSearchTool } from "../tools/docman/search.js";
import { createDocClassifyTool } from "../tools/docman/classify.js";
import { createDocTagTool, createDocUntagTool } from "../tools/docman/tag.js";
import { createDocLinkTool, createDocUnlinkTool } from "../tools/docman/link.js";
import { createDocRelateTool, createDocUnrelateTool, createDocRelationsTool } from "../tools/docman/relate.js";
import { createDocLabelsTool, createDocEntitiesTool, createDocEntityKindsTool, createDocDocTypesTool } from "../tools/docman/labels.js";

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
