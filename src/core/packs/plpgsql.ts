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
import type { DbClient } from "../connection.js";
import type { ToolPack, WithClient } from "../container.js";
import { buildModuleRegistry } from "../pgm/registry.js";
import { createCoverageTool } from "../tools/plpgsql/coverage.js";
import { createDocTool } from "../tools/plpgsql/doc.js";
import { createExplainTool } from "../tools/plpgsql/explain.js";
import { createFuncDelTool } from "../tools/plpgsql/func-del.js";
import { createFuncEditTool } from "../tools/plpgsql/func-edit.js";
import { createFuncLoadTool } from "../tools/plpgsql/func-load.js";
import { createFuncSaveTool } from "../tools/plpgsql/func-save.js";
import { createFuncSetTool, createSetFunction } from "../tools/plpgsql/func-set.js";
// Shared services
// Tool factories
import { createGetTool, resolveUri } from "../tools/plpgsql/get.js";
import { createHealthTool } from "../tools/plpgsql/health.js";
import { createMsgInboxTool, createMsgTool } from "../tools/plpgsql/msg.js";
import { createPackTool } from "../tools/plpgsql/pack.js";
import { createPreviewTool } from "../tools/plpgsql/preview.js";
import { createQueryTool } from "../tools/plpgsql/query.js";
import { createSchemaTool } from "../tools/plpgsql/schema.js";
import { createSearchTool } from "../tools/plpgsql/search.js";
import { createTestTool, formatTestReport, runTests } from "../tools/plpgsql/test.js";
import { createVisualTool } from "../tools/plpgsql/visual.js";

export const plpgsqlPack: ToolPack = (container: AwilixContainer, config: Record<string, unknown>) => {
  const connectionString =
    (config.connectionString as string) ??
    process.env.PLPGSQL_CONNECTION ??
    process.env.DATABASE_URL ??
    "postgresql://postgres@localhost:5432/postgres";

  container.register({
    // --- Infrastructure ---

    pool: asFunction(() => new Pool({ connectionString, max: 5 }))
      .singleton()
      .disposer((pool: Pool) => pool.end()),

    withClient: asFunction(({ pool }: { pool: Pool }) => {
      const fn: WithClient = async <T>(cb: (client: DbClient) => Promise<T>): Promise<T> => {
        const client = await pool.connect();
        try {
          return await cb(client);
        } finally {
          // Clean up any aborted transaction before returning to pool
          await client.query("ROLLBACK").catch(() => {});
          client.release();
        }
      };
      return fn;
    }).singleton(),

    // --- Shared services (used across tools via injection) ---
    // Wrapped in asFunction so they participate in DI lifecycle
    // and the pool/withClient aren't eagerly resolved.

    resolveUri: asFunction(() => resolveUri).singleton(),
    runTests: asFunction(() => runTests).singleton(),
    formatTestReport: asFunction(() => formatTestReport).singleton(),

    moduleRegistry: asValue(
      (() => {
        // Find workspace root synchronously, then build registry (async)
        let dir = process.cwd();
        for (let i = 0; i < 10; i++) {
          if (fsSync.existsSync(pathMod.join(dir, "modules"))) {
            return buildModuleRegistry(dir);
          }
          dir = pathMod.dirname(dir);
        }
        return buildModuleRegistry(process.cwd());
      })(),
    ),

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
    funcDelTool: asFunction(createFuncDelTool).singleton(),
    msgTool: asFunction(createMsgTool).singleton(),
    msgInboxTool: asFunction(createMsgInboxTool).singleton(),
    previewTool: asFunction(createPreviewTool).singleton(),
    healthTool: asFunction(createHealthTool).singleton(),
    visualTool: asFunction(createVisualTool).singleton(),
  });
};
