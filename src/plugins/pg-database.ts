import { asFunction } from "awilix";
import { Pool } from "pg";
import { resolveUri } from "../commands/plpgsql/get.js";
import { createBroadcastService } from "../core/broadcast.js";
import type { Plugin } from "../core/plugin.js";
import { attachPoolErrorHandler, createWithClient } from "../core/pool.js";

export const pgDatabasePlugin: Plugin = {
  id: "pg-database",
  name: "Database Infrastructure",
  capabilities: ["database"],

  register(container, config) {
    const connectionString =
      (config.connectionString as string) ??
      process.env.PLPGSQL_CONNECTION ??
      process.env.DATABASE_URL ??
      "postgresql://postgres@localhost:5432/postgres";

    container.register({
      pool: asFunction(() => attachPoolErrorHandler(new Pool({ connectionString, max: 5 })))
        .singleton()
        .disposer((pool: Pool) => pool.end()),

      withClient: asFunction(({ pool }: { pool: Pool }) => {
        return createWithClient(pool);
      }).singleton(),

      resolveUri: asFunction(() => resolveUri).singleton(),
      broadcast: asFunction(createBroadcastService).singleton(),
    });
  },
};
