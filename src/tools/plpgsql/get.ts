import { z } from "zod";
import type { DbClient } from "../../connection.js";
import type { ToolHandler, WithClient } from "../../container.js";
import { text, wrap } from "../../helpers.js";
import { PlUri } from "../../uri.js";
import { queryCatalog, formatCatalog } from "../../resources/catalog.js";
import { querySchema, formatSchema } from "../../resources/schema.js";
import { queryFunction, formatFunction } from "../../resources/function.js";
import { queryTable, formatTable } from "../../resources/table.js";
import { queryTrigger, formatTrigger } from "../../resources/trigger.js";
import { queryType, formatType } from "../../resources/type.js";
import { resolveDoc, resolveDocIndex } from "../../workbench.js";
import { computeContextToken } from "../../context-token.js";

// --- Shared service (registered in container, injected into set) ---

export async function resolveUri(uri: string, client: DbClient): Promise<string> {
  // plpgsql://workbench/doc/* -> documentation
  const docMatch = uri.match(/^plpgsql:\/\/workbench\/doc\/(.+)$/);
  if (docMatch) {
    return await resolveDoc(client, docMatch[1]);
  }
  if (uri === "plpgsql://workbench/doc" || uri === "plpgsql://workbench") {
    return await resolveDocIndex(client);
  }

  // plpgsql:// -> catalog
  if (uri === "plpgsql://" || uri === "plpgsql://catalog") {
    const entries = await queryCatalog(client);
    const next = entries.map((e) => `pg_get ${PlUri.schema(e.name)}`);
    return wrap(uri, "full", formatCatalog(entries), next);
  }

  // plpgsql://schema/kind/* -> batch get all of kind
  const glob = uri.match(/^plpgsql:\/\/(\w+)\/(\w+)\/\*$/);
  if (glob) {
    const [, schema, kind] = glob;
    const overview = await querySchema(client, schema);
    const results: string[] = [];

    if (kind === "function") {
      for (const f of overview.functions) {
        const fn = await queryFunction(client, schema, f.name);
        if (fn) results.push(formatFunction(fn));
      }
    } else if (kind === "table") {
      for (const t of overview.tables) {
        const tbl = await queryTable(client, schema, t.name);
        if (tbl) results.push(formatTable(tbl));
      }
    } else if (kind === "trigger") {
      for (const tr of overview.triggers) {
        const trg = await queryTrigger(client, schema, tr.name);
        if (trg) results.push(formatTrigger(trg));
      }
    }
    const body = results.length > 0 ? results.join("\n---\n") : `no ${kind}s in ${schema}`;
    return wrap(uri, "full", body, [`pg_get ${PlUri.schema(schema)}`]);
  }

  // plpgsql://schema/kind/name -> single resource
  const parsed = PlUri.parse(uri);
  if (!parsed) return `✗ invalid URI: ${uri}`;

  if (!parsed.kind) {
    const overview = await querySchema(client, parsed.schema);
    const next: string[] = [];
    if (overview.functions.length > 0) next.push(`pg_get ${PlUri.schema(parsed.schema)}/function/*`);
    if (overview.tables.length > 0) next.push(`pg_get ${PlUri.schema(parsed.schema)}/table/*`);
    next.push(`pg_search schema:${parsed.schema} name:%pattern%`);
    return wrap(uri, "full", formatSchema(overview), next);
  }

  switch (parsed.kind) {
    case "function": {
      const fn = await queryFunction(client, parsed.schema, parsed.name!);
      if (!fn) return `function ${parsed.schema}.${parsed.name} not found`;
      const token = await computeContextToken(client, parsed.schema, parsed.name!);
      const next: string[] = [];
      for (const t of fn.tables_used) next.push(`pg_get ${PlUri.table(fn.schema, t.name)}`);
      for (const c of fn.callers.slice(0, 3)) {
        const name = c.includes(".") ? c.split(".")[1] : c;
        const schema = c.includes(".") ? c.split(".")[0] : fn.schema;
        next.push(`pg_get ${PlUri.fn(schema, name)}`);
      }
      if (next.length === 0) next.push(`pg_search content:${fn.name}`);
      const formatted = formatFunction(fn) + (token ? `\n  context_token: ${token}` : "");
      return wrap(uri, "full", formatted, next);
    }
    case "table": {
      const tbl = await queryTable(client, parsed.schema, parsed.name!);
      if (!tbl) return `table ${parsed.schema}.${parsed.name} not found`;
      const next = tbl.used_by.slice(0, 3).map((u) => `pg_get ${PlUri.fn(parsed.schema, u.name)}`);
      if (next.length === 0) next.push(`pg_search content:${parsed.name}`);
      return wrap(uri, "full", formatTable(tbl), next);
    }
    case "trigger": {
      const trg = await queryTrigger(client, parsed.schema, parsed.name!);
      if (!trg) return `trigger ${parsed.schema}.${parsed.name} not found`;
      return wrap(uri, "full", formatTrigger(trg), [
        `pg_get ${PlUri.table(parsed.schema, trg.table)}`,
        `pg_get ${PlUri.fn(parsed.schema, trg.function)}`,
      ]);
    }
    case "type": {
      const typ = await queryType(client, parsed.schema, parsed.name!);
      if (!typ) return `type ${parsed.schema}.${parsed.name} not found`;
      return wrap(uri, "full", formatType(typ), [`pg_search content:${parsed.name}`]);
    }
  }
}

// --- Tool factory ---

export function createGetTool({ withClient, resolveUri }: {
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
        uri: z.union([
          z.string().describe("Single URI or glob pattern"),
          z.array(z.string()).describe("Multiple URIs"),
        ]).describe("plpgsql:// URI(s)"),
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
