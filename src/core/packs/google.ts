/**
 * google pack — registers Google OAuth2 auth service and Gmail tools.
 *
 * Config is read from workbench.config(google, *) at runtime, not from env vars.
 */

import { type AwilixContainer, asFunction } from "awilix";
import type { ToolPack } from "../container.js";

import { createGmailClient } from "../tools/google/auth.js";
import { createGmailAttachmentTool } from "../tools/google/gmail-attachment.js";
import { createGmailReadTool } from "../tools/google/gmail-read.js";
import { createGmailSearchTool } from "../tools/google/gmail-search.js";

export const googlePack: ToolPack = (container: AwilixContainer) => {
  container.register({
    gmailClient: asFunction(createGmailClient).singleton(),

    gmailSearchTool: asFunction(createGmailSearchTool).singleton(),
    gmailReadTool: asFunction(createGmailReadTool).singleton(),
    gmailAttachmentTool: asFunction(createGmailAttachmentTool).singleton(),
  });
};
