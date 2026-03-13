#!/usr/bin/env node

/**
 * sync-tools — Syncs tool definitions from code into workbench.toolbox/toolbox_tool tables.
 *
 * Reads the Awilix registry, creates an "admin" toolbox with all tools.
 * Run after deploy/migration: npm run sync-tools
 */

import { Pool } from "pg";
import { toJSONSchema } from "zod";
import { buildContainer, type ToolPack, type ToolHandler } from "./container.js";
import { plpgsqlPack } from "./packs/plpgsql.js";
import { docstorePack } from "./packs/docstore.js";
import { googlePack } from "./packs/google.js";
import { docmanPack } from "./packs/docman.js";

const connectionString =
  process.env.PLPGSQL_CONNECTION ??
  process.env.DATABASE_URL ??
  "postgresql://postgres@localhost:5432/postgres";

const packConfigs: Record<string, Record<string, unknown>> = {
  plpgsql: {},
  docstore: {},
  google: {},
  docman: {},
};
const packImpls: Record<string, ToolPack> = {
  plpgsql: plpgsqlPack,
  docstore: docstorePack,
  google: googlePack,
  docman: docmanPack,
};

const container = buildContainer({ packs: packConfigs }, packImpls);
const registry: Map<string, ToolHandler> = container.resolve("toolRegistry");
const toolNames = [...registry.keys()];

const pool = new Pool({ connectionString });

try {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // Ensure admin toolbox exists
    await client.query(
      `INSERT INTO workbench.toolbox (name, description)
       VALUES ('admin', 'All tools — development & administration')
       ON CONFLICT (name) DO NOTHING`
    );

    // Sync tools: upsert with description + input_schema
    for (const [name, handler] of registry) {
      const desc = handler.metadata?.description ?? null;
      const schema = handler.metadata?.schema
        ? JSON.stringify(toJSONSchema(handler.metadata.schema))
        : null;
      await client.query(
        `INSERT INTO workbench.toolbox_tool (toolbox_name, tool_name, description, input_schema)
         VALUES ('admin', $1, $2, $3)
         ON CONFLICT (toolbox_name, tool_name)
         DO UPDATE SET description = EXCLUDED.description, input_schema = EXCLUDED.input_schema`,
        [name, desc, schema]
      );
    }

    // Remove tools no longer in code
    await client.query(
      `DELETE FROM workbench.toolbox_tool
       WHERE toolbox_name = 'admin'
         AND tool_name != ALL($1)`,
      [toolNames]
    );

    await client.query("COMMIT");
    console.log(`Synced ${toolNames.length} tools into toolbox "admin": ${toolNames.join(", ")}`);
  } finally {
    client.release();
  }
} finally {
  await pool.end();
  await container.dispose();
}
