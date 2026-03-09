import { z } from "zod";
import type { ToolHandler, WithClient } from "../../container.js";
import { text } from "../../helpers.js";

export function createDocImportTool({
  withClient,
  scanTool,
}: {
  withClient: WithClient;
  scanTool: ToolHandler;
}): ToolHandler {
  return {
    metadata: {
      name: "doc_import",
      description:
        "Import documents from a directory for classification.\n" +
        "Scans the directory (via fs_scan), then registers files in docman.\n" +
        "Imported documents appear in doc_inbox for classification.\n" +
        "Default path: workbench.config(docman, documentsRoot).",
      schema: z.object({
        path: z.string().optional().describe("Directory to import (default: from DB config)"),
        ext: z.string().optional().describe("Filter by extension (e.g. '.pdf')"),
        recursive: z.boolean().optional().describe("Scan recursively (default: true)"),
      }),
    },
    handler: async (args, extra) => {
      const { ext, recursive } = args as {
        path?: string; ext?: string; recursive?: boolean;
      };

      let dir = args.path as string | undefined;
      if (!dir) {
        dir = await withClient(async (client) => {
          const res = await client.query(
            `SELECT value FROM workbench.config WHERE app = 'docman' AND key = 'documentsRoot'`
          );
          if (res.rows.length === 0) {
            throw new Error("Config missing: workbench.config(docman, documentsRoot). Set it with pg_query.");
          }
          return res.rows[0].value as string;
        });
      }

      // 1. Scan filesystem -> docstore.file
      await scanTool.handler(
        { path: dir, ext, recursive: recursive ?? true },
        extra,
      );

      // 2. Register in docman.document via PL/pgSQL
      return await withClient(async (client) => {
        const res = await client.query(
          `SELECT * FROM docman.register($1, 'filesystem')`,
          [dir]
        );
        const { registered, skipped } = res.rows[0];

        return text(
          `Imported from ${dir}\n` +
          `new: ${registered}, skipped: ${skipped}\n\n` +
          `next:\n  - doc_inbox\n  - doc_search name:%pattern%`
        );
      });
    },
  };
}
