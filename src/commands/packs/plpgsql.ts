/**
 * plpgsql pack — registers the PostgreSQL connection, shared services,
 * and all plpgsql-workbench tools into the Awilix container.
 *
 * Dependencies are resolved by parameter name (Awilix PROXY mode).
 */

import fsSync from "node:fs";
import pathMod from "node:path";
import { type AwilixContainer, asFunction, asValue } from "awilix";
import { Pool } from "pg";
import { createBroadcastService } from "../../core/broadcast.js";
import type { DbClient } from "../../core/connection.js";
import type { ToolPack, WithClient } from "../../core/container.js";
import { buildModuleRegistry } from "../../core/pgm/registry.js";
import { createPgmModuleApplyTool } from "../pgm/module-apply.js";
import { createPlxModuleDropTool } from "../pgm/module-drop.js";
import { createPgmModuleStatusTool } from "../pgm/module-status.js";
import { createPlxModuleTestTool } from "../pgm/module-test.js";
import { createAlterTool } from "../plpgsql/alter.js";
import { createBroadcastTool } from "../plpgsql/broadcast.js";
import { createCoverageTool } from "../plpgsql/coverage.js";
import { createDocTool } from "../plpgsql/doc.js";
import { createExplainTool } from "../plpgsql/explain.js";
import { createFuncBulkDelTool } from "../plpgsql/func-bulk-del.js";
import { createFuncDelTool } from "../plpgsql/func-del.js";
import { createFuncEditTool } from "../plpgsql/func-edit.js";
import { createFuncLoadTool } from "../plpgsql/func-load.js";
import { createFuncRenameTool } from "../plpgsql/func-rename.js";
import { createFuncSaveTool } from "../plpgsql/func-save.js";
import { createFuncSetTool, createSetFunction } from "../plpgsql/func-set.js";
// Shared services
// Tool factories
import { createGetTool, resolveUri } from "../plpgsql/get.js";
import { createHealthTool } from "../plpgsql/health.js";
import { createMsgInboxTool, createMsgTool } from "../plpgsql/msg.js";
import { createPackTool } from "../plpgsql/pack.js";
import { createPreviewTool } from "../plpgsql/preview.js";
import { createQueryTool } from "../plpgsql/query.js";
import { createSchemaTool } from "../plpgsql/schema.js";
import { createSearchTool } from "../plpgsql/search.js";
import { createTestTool, formatTestReport, runTests } from "../plpgsql/test.js";
import { createVisualTool } from "../plpgsql/visual.js";
import { createRuntimeApplyTool } from "../runtime/apply.js";
import { createRuntimeStatusTool } from "../runtime/status.js";
import { createRuntimeTestTool } from "../runtime/test.js";

type PoolLogger = Pick<Console, "error">;
type PgPoolLike = Pick<Pool, "connect" | "on">;
type PgPoolClientLike = DbClient & {
  release: (destroy?: boolean) => void;
  on: (event: "error", listener: (error: Error) => void) => void;
  removeListener?: (event: "error", listener: (error: Error) => void) => void;
};

export function attachPoolErrorHandler(pool: Pool, logger: PoolLogger = console): Pool {
  pool.on("error", (error: Error) => {
    logger.error("[plpgsql] Unexpected idle PostgreSQL client error", error);
  });
  return pool;
}

export function createWithClient(pool: PgPoolLike, logger: PoolLogger = console, tenantId = "dev"): WithClient {
  const fn: WithClient = async <T>(cb: (client: DbClient) => Promise<T>): Promise<T> => {
    const client = (await pool.connect()) as PgPoolClientLike;
    let broken = false;
    const onClientError = (error: Error) => {
      broken = true;
      logger.error("[plpgsql] PostgreSQL client error during tool execution", error);
    };

    client.on("error", onClientError);
    try {
      await client.query("SELECT set_config('app.tenant_id', $1, false)", [tenantId]);
      return await cb(client);
    } finally {
      client.removeListener?.("error", onClientError);
      await client.query("ROLLBACK").catch(() => {});
      client.release(broken);
    }
  };
  return fn;
}

export const plpgsqlPack: ToolPack = (container: AwilixContainer, config: Record<string, unknown>) => {
  const connectionString =
    (config.connectionString as string) ??
    process.env.PLPGSQL_CONNECTION ??
    process.env.DATABASE_URL ??
    "postgresql://postgres@localhost:5432/postgres";

  container.register({
    // --- Infrastructure ---

    pool: asFunction(() => attachPoolErrorHandler(new Pool({ connectionString, max: 5 })))
      .singleton()
      .disposer((pool: Pool) => pool.end()),

    withClient: asFunction(({ pool }: { pool: Pool }) => {
      return createWithClient(pool);
    }).singleton(),

    // --- Shared services (used across tools via injection) ---
    // Wrapped in asFunction so they participate in DI lifecycle
    // and the pool/withClient aren't eagerly resolved.

    resolveUri: asFunction(() => resolveUri).singleton(),
    runTests: asFunction(() => runTests).singleton(),
    formatTestReport: asFunction(() => formatTestReport).singleton(),

    ...(() => {
      // Walk up once to find workspace root (has runtime/ or modules/)
      let root = process.cwd();
      for (let i = 0; i < 10; i++) {
        if (fsSync.existsSync(pathMod.join(root, "modules")) || fsSync.existsSync(pathMod.join(root, "runtime"))) {
          return { moduleRegistry: asValue(buildModuleRegistry(root)), workspaceRoot: asValue(root) };
        }
        root = pathMod.dirname(root);
      }
      root = process.cwd();
      return { moduleRegistry: asValue(buildModuleRegistry(root)), workspaceRoot: asValue(root) };
    })(),

    setFunction: asFunction(createSetFunction).singleton(),

    // --- Tools ---

    getTool: asFunction(createGetTool).singleton(),
    searchTool: asFunction(createSearchTool).singleton(),
    funcSetTool: asFunction(createFuncSetTool).singleton(),
    funcEditTool: asFunction(createFuncEditTool).singleton(),
    queryTool: asFunction(createQueryTool).singleton(),
    explainTool: asFunction(createExplainTool).singleton(),
    testTool: asFunction(createTestTool).singleton(),
    coverageTool: asFunction(createCoverageTool).singleton(),
    funcSaveTool: asFunction(createFuncSaveTool).singleton(),
    funcLoadTool: asFunction(createFuncLoadTool).singleton(),
    schemaTool: asFunction(createSchemaTool).singleton(),
    docTool: asFunction(createDocTool).singleton(),
    packTool: asFunction(createPackTool).singleton(),
    pgmModuleStatusTool: asFunction(createPgmModuleStatusTool).singleton(),
    pgmModuleApplyTool: asFunction(createPgmModuleApplyTool).singleton(),
    plxModuleDropTool: asFunction(createPlxModuleDropTool).singleton(),
    plxModuleTestTool: asFunction(createPlxModuleTestTool).singleton(),
    runtimeStatusTool: asFunction(createRuntimeStatusTool).singleton(),
    runtimeApplyTool: asFunction(createRuntimeApplyTool).singleton(),
    runtimeTestTool: asFunction(createRuntimeTestTool).singleton(),
    funcDelTool: asFunction(createFuncDelTool).singleton(),
    funcRenameTool: asFunction(createFuncRenameTool).singleton(),
    funcBulkDelTool: asFunction(createFuncBulkDelTool).singleton(),
    alterTool: asFunction(createAlterTool).singleton(),
    msgTool: asFunction(createMsgTool).singleton(),
    msgInboxTool: asFunction(createMsgInboxTool).singleton(),
    previewTool: asFunction(createPreviewTool).singleton(),
    healthTool: asFunction(createHealthTool).singleton(),
    visualTool: asFunction(createVisualTool).singleton(),

    // AI broadcast service (live notifications to browser)
    broadcast: asFunction(createBroadcastService).singleton(),
    broadcastTool: asFunction(createBroadcastTool).singleton(),
  });
};
