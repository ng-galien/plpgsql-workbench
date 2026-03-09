/**
 * Google OAuth2 auth service.
 *
 * Manages token lifecycle: load saved token, interactive OAuth flow, save refresh token.
 * Config is read lazily from workbench.config(google, *) on first connect().
 */

import fs from "fs";
import path from "path";
import { google } from "googleapis";
import { authenticate } from "@google-cloud/local-auth";
import type { WithClient } from "../../container.js";

export interface GoogleAuthConfig {
  credentialsPath: string;
  tokenPath: string;
  scopes: string[];
  inboxRoot: string;
}

export interface GmailClient {
  connect: () => Promise<void>;
  getGmail: () => ReturnType<typeof google.gmail>;
  getConfig: () => GoogleAuthConfig;
}

export function createGmailClient({ withClient }: {
  withClient: WithClient;
}): GmailClient {
  let config: GoogleAuthConfig | null = null;
  let auth: any = null;
  let connected = false;

  async function loadConfig(): Promise<GoogleAuthConfig> {
    if (config) return config;
    config = await withClient(async (client) => {
      const res = await client.query(
        `SELECT key, value FROM workbench.config WHERE app = 'google'`
      );
      const map = Object.fromEntries(res.rows.map((r: any) => [r.key, r.value]));
      if (!map.credentialsPath) {
        throw new Error(
          "Config missing: workbench.config(google, credentialsPath).\n" +
          "fix_hint: pg_query sql:INSERT INTO workbench.config VALUES ('google','credentialsPath','/path/to/credentials.json')"
        );
      }
      if (!map.tokenPath) {
        throw new Error(
          "Config missing: workbench.config(google, tokenPath).\n" +
          "fix_hint: pg_query sql:INSERT INTO workbench.config VALUES ('google','tokenPath','/path/to/token.json')"
        );
      }
      return {
        credentialsPath: map.credentialsPath,
        tokenPath: map.tokenPath,
        scopes: map.scopes ? map.scopes.split(",") : ["https://www.googleapis.com/auth/gmail.readonly"],
        inboxRoot: map.inboxRoot ?? "",
      };
    });
    return config;
  }

  function ensureDir(filePath: string): void {
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  }

  async function connect(): Promise<void> {
    if (connected) return;
    const cfg = await loadConfig();

    // 1. Try saved token
    if (fs.existsSync(cfg.tokenPath)) {
      const data = fs.readFileSync(cfg.tokenPath, "utf-8");
      auth = google.auth.fromJSON(JSON.parse(data));
      connected = true;
      return;
    }

    // 2. Interactive OAuth — opens browser for consent, local HTTP callback
    if (!fs.existsSync(cfg.credentialsPath)) {
      throw new Error(`Google credentials not found: ${cfg.credentialsPath}`);
    }
    const client = await authenticate({ scopes: cfg.scopes, keyfilePath: cfg.credentialsPath });
    if (client.credentials) {
      const keys = JSON.parse(fs.readFileSync(cfg.credentialsPath, "utf-8"));
      const key = keys.installed || keys.web;
      const payload = JSON.stringify({
        type: "authorized_user",
        client_id: key.client_id,
        client_secret: key.client_secret,
        refresh_token: client.credentials.refresh_token,
      });
      ensureDir(cfg.tokenPath);
      fs.writeFileSync(cfg.tokenPath, payload);
    }
    auth = client;
    connected = true;
  }

  function getGmail(): ReturnType<typeof google.gmail> {
    if (!connected || !auth) {
      throw new Error("Gmail not connected — call connect() first");
    }
    return google.gmail({ version: "v1", auth: auth as any });
  }

  function getConfig(): GoogleAuthConfig {
    if (!config) {
      throw new Error("Gmail not connected — call connect() first to load config");
    }
    return config;
  }

  return { connect, getGmail, getConfig };
}

/**
 * Ensure the Gmail client is connected, then return a gmail service instance.
 * Triggers interactive OAuth if no saved token exists.
 */
export async function ensureGmailConnected(client: GmailClient): Promise<ReturnType<typeof google.gmail>> {
  await client.connect();
  return client.getGmail();
}
