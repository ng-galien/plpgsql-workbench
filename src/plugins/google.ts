import { asFunction } from "awilix";
import type { Plugin } from "../core/plugin.js";
import { createGmailClient } from "../integrations/google/auth.js";
import { createGmailAttachmentTool } from "../integrations/google/gmail-attachment.js";
import { createGmailReadTool } from "../integrations/google/gmail-read.js";
import { createGmailSearchTool } from "../integrations/google/gmail-search.js";

export const googlePlugin: Plugin = {
  id: "google",
  name: "Google Integration",
  requires: ["withClient"],
  capabilities: ["gmail"],

  register(container) {
    container.register({
      gmailClient: asFunction(createGmailClient).singleton(),
      gmailSearchTool: asFunction(createGmailSearchTool).singleton(),
      gmailReadTool: asFunction(createGmailReadTool).singleton(),
      gmailAttachmentTool: asFunction(createGmailAttachmentTool).singleton(),
    });
  },
};
