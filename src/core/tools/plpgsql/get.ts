import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { computeContextToken } from "../../context-token.js";
import { text } from "../../helpers.js";
import { formatCatalog, queryCatalog } from "../../resources/catalog.js";
import { formatFunction, queryFunction } from "../../resources/function.js";
import { formatSchema, querySchema } from "../../resources/schema.js";
import { formatTable, queryTable } from "../../resources/table.js";
import { formatTrigger, queryTrigger } from "../../resources/trigger.js";
import { formatType, queryType } from "../../resources/type.js";
import { formatReadDocument } from "../../tooling/primitives/read.js";
import { resolvePlpgsqlTarget } from "../../tooling/primitives/target-resolution.js";
import { PlUri } from "../../uri.js";
import { resolveDoc, resolveDocIndex } from "../../workbench.js";

// --- Shared service (registered in container, injected into set) ---

export async function resolveUri(uri: string, client: DbClient): Promise<string> {
  const target = resolvePlpgsqlTarget(uri);

  switch (target.kind) {
    case "doc_topic":
      return await resolveDoc(client, target.topic);
    case "doc_index":
      return await resolveDocIndex(client);
    case "catalog": {
      const entries = await queryCatalog(client);
      const next = entries.map((entry) => `pg_get ${PlUri.schema(entry.name)}`);
      return formatReadDocument({
        uri: target.uri,
        completeness: "full",
        body: formatCatalog(entries),
        next,
      });
    }
    case "glob": {
      const overview = await querySchema(client, target.schema);
      const results: string[] = [];

      if (target.resourceKind === "function") {
        for (const resource of overview.functions) {
          const fn = await queryFunction(client, target.schema, resource.name);
          if (fn) results.push(formatFunction(fn));
        }
      } else if (target.resourceKind === "table") {
        for (const resource of overview.tables) {
          const table = await queryTable(client, target.schema, resource.name);
          if (table) results.push(formatTable(table));
        }
      } else if (target.resourceKind === "trigger") {
        for (const resource of overview.triggers) {
          const trigger = await queryTrigger(client, target.schema, resource.name);
          if (trigger) results.push(formatTrigger(trigger));
        }
      }

      return formatReadDocument({
        uri: target.uri,
        completeness: "full",
        body: results.length > 0 ? results.join("\n---\n") : `no ${target.resourceKind}s in ${target.schema}`,
        next: [`pg_get ${PlUri.schema(target.schema)}`],
      });
    }
    case "schema": {
      const overview = await querySchema(client, target.schema);
      const next: string[] = [];
      if (overview.functions.length > 0) next.push(`pg_get ${PlUri.schema(target.schema)}/function/*`);
      if (overview.tables.length > 0) next.push(`pg_get ${PlUri.schema(target.schema)}/table/*`);
      next.push(`pg_search schema:${target.schema} name:%pattern%`);
      return formatReadDocument({
        uri: target.uri,
        completeness: "full",
        body: formatSchema(overview),
        next,
      });
    }
    case "resource":
      if (target.resourceKind === "function") {
        const fn = await queryFunction(client, target.schema, target.name);
        if (!fn) return `function ${target.schema}.${target.name} not found`;
        const token = await computeContextToken(client, target.schema, target.name);
        const next: string[] = [];
        for (const t of fn.tables_used) next.push(`pg_get ${PlUri.table(fn.schema, t.name)}`);
        for (const c of fn.callers.slice(0, 3)) {
          const name = c.includes(".") ? c.split(".")[1]! : c;
          const schema = c.includes(".") ? c.split(".")[0]! : fn.schema;
          next.push(`pg_get ${PlUri.fn(schema, name)}`);
        }
        if (next.length === 0) next.push(`pg_search content:${fn.name}`);
        const formatted = formatFunction(fn) + (token ? `\n  context_token: ${token}` : "");
        return formatReadDocument({
          uri: target.uri,
          completeness: "full",
          body: formatted,
          next,
        });
      }
      if (target.resourceKind === "table") {
        const tbl = await queryTable(client, target.schema, target.name);
        if (!tbl) return `table ${target.schema}.${target.name} not found`;
        const next = tbl.used_by.slice(0, 3).map((u) => `pg_get ${PlUri.fn(target.schema, u.name)}`);
        if (next.length === 0) next.push(`pg_search content:${target.name}`);
        return formatReadDocument({
          uri: target.uri,
          completeness: "full",
          body: formatTable(tbl),
          next,
        });
      }
      if (target.resourceKind === "trigger") {
        const trg = await queryTrigger(client, target.schema, target.name);
        if (!trg) return `trigger ${target.schema}.${target.name} not found`;
        return formatReadDocument({
          uri: target.uri,
          completeness: "full",
          body: formatTrigger(trg),
          next: [`pg_get ${PlUri.table(target.schema, trg.table)}`, `pg_get ${PlUri.fn(target.schema, trg.function)}`],
        });
      }
      if (target.resourceKind === "type") {
        const typ = await queryType(client, target.schema, target.name);
        if (!typ) return `type ${target.schema}.${target.name} not found`;
        return formatReadDocument({
          uri: target.uri,
          completeness: "full",
          body: formatType(typ),
          next: [`pg_search content:${target.name}`],
        });
      }
      return `✗ invalid URI: ${uri}`;
    case "invalid":
      return `✗ ${target.problem}`;
  }
}

// --- Tool factory ---

export function createGetTool({
  withClient,
  resolveUri,
}: {
  withClient: WithClient;
  resolveUri: (uri: string, client: DbClient) => Promise<string>;
}): ToolHandler {
  return {
    metadata: {
      name: "pg_get",
      description:
        "Navigate the database by URI. Returns compact text with navigable URIs.\n" +
        "Levels: plpgsql:// (catalog) -> plpgsql://schema -> plpgsql://schema/function/name\n" +
        "Batch: plpgsql://schema/function/* (all functions). Multi: pass URI array.\n" +
        "Kinds: function, table, trigger, type",
      schema: z.object({
        uri: z
          .union([z.string().describe("Single URI or glob pattern"), z.array(z.string()).describe("Multiple URIs")])
          .describe("plpgsql:// URI(s)"),
      }),
    },
    handler: async (args, _extra) => {
      const uri = args.uri as string | string[];
      return withClient(async (client) => {
        const uris = Array.isArray(uri) ? uri : [uri];
        const results: string[] = [];
        for (const u of uris) results.push(await resolveUri(u, client));
        return text(results.join("\n===\n"));
      });
    },
  };
}
