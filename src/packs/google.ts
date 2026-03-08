/**
 * google pack — registers Google OAuth2 auth service and Gmail tools.
 *
 * Only loaded when GOOGLE_CREDENTIALS_PATH env var is set.
 */

import os from "os";
import path from "path";
import { asFunction, asValue, type AwilixContainer } from "awilix";
import type { ToolPack } from "../container.js";

import { createGmailClient, type GoogleAuthConfig } from "../tools/google/auth.js";
import { createGmailSearchTool } from "../tools/google/gmail-search.js";
import { createGmailReadTool } from "../tools/google/gmail-read.js";
import { createGmailAttachmentTool } from "../tools/google/gmail-attachment.js";

export const googlePack: ToolPack = (container: AwilixContainer, config: Record<string, unknown>) => {
  const defaultConfigDir = path.join(os.homedir(), ".config", "plpgsql-workbench");

  const googleAuthConfig: GoogleAuthConfig = {
    credentialsPath: (config.credentialsPath as string) ??
      process.env.GOOGLE_CREDENTIALS_PATH ??
      path.join(defaultConfigDir, "google-credentials.json"),
    tokenPath: (config.tokenPath as string) ??
      process.env.GOOGLE_TOKEN_PATH ??
      path.join(defaultConfigDir, "google-token.json"),
    scopes: (config.scopes as string[]) ?? [
      "https://www.googleapis.com/auth/gmail.readonly",
    ],
    inboxRoot: (config.inboxRoot as string) ??
      process.env.GMAIL_INBOX_ROOT ??
      "",
  };

  container.register({
    googleAuthConfig: asValue(googleAuthConfig),
    gmailClient: asFunction(createGmailClient).singleton(),

    gmailSearchTool: asFunction(createGmailSearchTool).singleton(),
    gmailReadTool: asFunction(createGmailReadTool).singleton(),
    gmailAttachmentTool: asFunction(createGmailAttachmentTool).singleton(),
  });
};
