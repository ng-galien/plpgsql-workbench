/**
 * Google OAuth2 auth service.
 *
 * Manages token lifecycle: load saved token, interactive OAuth flow, save refresh token.
 * Injected into Gmail tools as `gmailClient` (a lazily-connected gmail service instance).
 */

import fs from "fs";
import path from "path";
import { google } from "googleapis";
import { authenticate } from "@google-cloud/local-auth";

export interface GoogleAuthConfig {
  credentialsPath: string;
  tokenPath: string;
  scopes: string[];
  inboxRoot: string;
}

export interface GmailClient {
  config: GoogleAuthConfig;
  connect: () => Promise<void>;
  getGmail: () => ReturnType<typeof google.gmail>;
}

export function createGmailClient({ googleAuthConfig }: {
  googleAuthConfig: GoogleAuthConfig;
}): GmailClient {
  const { credentialsPath, tokenPath, scopes } = googleAuthConfig;

  let auth: any = null;
  let connected = false;

  function ensureDir(filePath: string): void {
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  }

  function loadSavedToken(): any | null {
    if (!fs.existsSync(tokenPath)) return null;
    const data = fs.readFileSync(tokenPath, "utf-8");
    return google.auth.fromJSON(JSON.parse(data));
  }

  function saveToken(client: any): void {
    const keys = JSON.parse(fs.readFileSync(credentialsPath, "utf-8"));
    const key = keys.installed || keys.web;
    const payload = JSON.stringify({
      type: "authorized_user",
      client_id: key.client_id,
      client_secret: key.client_secret,
      refresh_token: client.credentials.refresh_token,
    });
    ensureDir(tokenPath);
    fs.writeFileSync(tokenPath, payload);
  }

  async function connect(): Promise<void> {
    if (connected) return;

    // 1. Try saved token
    const saved = loadSavedToken();
    if (saved) {
      auth = saved;
      connected = true;
      return;
    }

    // 2. Interactive OAuth — opens browser for consent, local HTTP callback
    if (!fs.existsSync(credentialsPath)) {
      throw new Error(`Google credentials not found: ${credentialsPath}`);
    }
    const client = await authenticate({ scopes, keyfilePath: credentialsPath });
    if (client.credentials) saveToken(client);
    auth = client;
    connected = true;
  }

  // Try silent reconnect at creation (no browser needed if token exists)
  try {
    const saved = loadSavedToken();
    if (saved) {
      auth = saved;
      connected = true;
    }
  } catch { /* start disconnected */ }

  /** Return a gmail service instance with the current auth. */
  function getGmail(): ReturnType<typeof google.gmail> {
    if (!connected || !auth) {
      throw new Error("Gmail not connected — call connect() first");
    }
    return google.gmail({ version: "v1", auth: auth as any });
  }

  return {
    config: googleAuthConfig,
    connect,
    getGmail,
  };
}

/**
 * Ensure the Gmail client is connected, then return a gmail service instance.
 * Triggers interactive OAuth if no saved token exists.
 */
export async function ensureGmailConnected(client: GmailClient): Promise<ReturnType<typeof google.gmail>> {
  await client.connect();
  return client.getGmail();
}
