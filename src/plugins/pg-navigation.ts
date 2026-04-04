import { asFunction } from "awilix";
import { createDocTool } from "../commands/plpgsql/doc.js";
import { createExplainTool } from "../commands/plpgsql/explain.js";
import { createGetTool } from "../commands/plpgsql/get.js";
import { createQueryTool } from "../commands/plpgsql/query.js";
import { createSchemaTool } from "../commands/plpgsql/schema.js";
import { createSearchTool } from "../commands/plpgsql/search.js";
import { type HookRule, inputStr, type Plugin } from "../core/plugin.js";

const DDL_RE =
  /\b(CREATE\s+(SCHEMA|TABLE|INDEX|EXTENSION|TYPE)|ALTER\s+(TABLE|SCHEMA|TYPE)|DROP\s+(SCHEMA|TABLE|INDEX|TYPE|EXTENSION))\b/i;
const FUNC_RE = /\bCREATE\s+(OR\s+REPLACE\s+)?FUNCTION\b/i;
const DESTRUCTIVE_RE = /\b(DROP\s+FUNCTION|TRUNCATE|GRANT\s+|REVOKE\s+)\b/i;

const WORKFLOW = [
  "Workflow strict:",
  "  1. DDL (schemas, tables, indexes) -> fichiers SQL sur disque + pg_schema",
  "  2. Fonctions PL/pgSQL -> pg_func_set pour creer/iterer + pg_test pour valider",
  "  3. Quand stable -> pg_func_save pour exporter en fichiers .sql",
  "  4. pg_query -> SELECT ad-hoc et DML donnees uniquement",
].join("\n");

export const pgNavigationPlugin: Plugin = {
  id: "pg-navigation",
  name: "Database Navigation & Query",
  requires: ["withClient"],

  register(container) {
    container.register({
      getTool: asFunction(createGetTool).singleton(),
      searchTool: asFunction(createSearchTool).singleton(),
      queryTool: asFunction(createQueryTool).singleton(),
      explainTool: asFunction(createExplainTool).singleton(),
      docTool: asFunction(createDocTool).singleton(),
      schemaTool: asFunction(createSchemaTool).singleton(),
    });
  },

  hooks(): HookRule[] {
    return [
      {
        toolPattern: /pg_query$/,
        evaluate(ctx) {
          const sql = inputStr(ctx, "sql");
          if (FUNC_RE.test(sql)) {
            return {
              action: "deny",
              reason: `pg_query interdit pour les fonctions. Utilise pg_func_set + pg_test.\n\n${WORKFLOW}`,
            };
          }
          if (DDL_RE.test(sql)) {
            return {
              action: "deny",
              reason: `pg_query interdit pour le DDL. Ecris un fichier SQL + pg_schema.\n\n${WORKFLOW}`,
            };
          }
          if (DESTRUCTIVE_RE.test(sql)) {
            return {
              action: "deny",
              reason: `pg_query interdit pour DROP FUNCTION / TRUNCATE / GRANT / REVOKE. Utilise pg_func_del pour supprimer une fonction.\n\n${WORKFLOW}`,
            };
          }
          return null;
        },
      },
      {
        toolPattern: /^(Write|Edit)$/,
        evaluate(ctx) {
          const filePath = inputStr(ctx, "file_path");
          const content = inputStr(ctx, "content") || inputStr(ctx, "new_string");
          if (filePath.endsWith(".func.sql")) {
            return {
              action: "deny",
              reason: `*.func.sql est genere par pg_pack. Utilise pg_func_set pour iterer, puis pg_pack pour exporter.\n\n${WORKFLOW}`,
            };
          }
          if (filePath.endsWith(".sql") && FUNC_RE.test(content)) {
            return {
              action: "deny",
              reason: `Interdit d'ecrire des fonctions dans des fichiers SQL. Utilise pg_func_set + pg_test, puis pg_func_save quand stable.\n\n${WORKFLOW}`,
            };
          }
          return null;
        },
      },
    ];
  },
};
