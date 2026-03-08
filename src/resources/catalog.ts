import type { DbClient } from "../connection.js";
import { PlUri } from "../uri.js";

export interface CatalogEntry {
  name: string;
  tables: number;
  functions: number;
  triggers: number;
}

// --- Query ---

export async function queryCatalog(client: DbClient): Promise<CatalogEntry[]> {
  const { rows } = await client.query<{
    schema_name: string;
    table_count: string;
    function_count: string;
    trigger_count: string;
  }>(`
    SELECT
      n.nspname AS schema_name,
      (SELECT count(*) FROM pg_class c
       WHERE c.relnamespace = n.oid AND c.relkind = 'r') AS table_count,
      (SELECT count(*) FROM pg_proc p
       JOIN pg_language l ON l.oid = p.prolang
       WHERE p.pronamespace = n.oid AND l.lanname = 'plpgsql') AS function_count,
      (SELECT count(DISTINCT t.tgname) FROM pg_trigger t
       JOIN pg_class c ON c.oid = t.tgrelid
       WHERE c.relnamespace = n.oid AND NOT t.tgisinternal) AS trigger_count
    FROM pg_namespace n
    WHERE n.nspname NOT LIKE 'pg_%'
      AND n.nspname != 'information_schema'
      AND n.nspname != 'plpgsql_workbench'
    ORDER BY n.nspname
  `);

  return rows.map((r) => ({
    name: r.schema_name,
    tables: parseInt(r.table_count),
    functions: parseInt(r.function_count),
    triggers: parseInt(r.trigger_count),
  }));
}

// --- Format ---

export function formatCatalog(entries: CatalogEntry[]): string {
  if (entries.length === 0) return "(no schemas)";
  const pad = Math.max(...entries.map((e) => e.name.length)) + 2;
  return entries
    .map((e) =>
      `${e.name.padEnd(pad)} ${summarizeCounts(e).padEnd(40)} ${PlUri.schema(e.name)}`,
    )
    .join("\n");
}

function summarizeCounts(e: CatalogEntry): string {
  const parts: string[] = [];
  if (e.tables > 0) parts.push(`${e.tables} ${e.tables === 1 ? "table" : "tables"}`);
  if (e.functions > 0) parts.push(`${e.functions} ${e.functions === 1 ? "function" : "functions"}`);
  if (e.triggers > 0) parts.push(`${e.triggers} ${e.triggers === 1 ? "trigger" : "triggers"}`);
  return parts.length > 0 ? parts.join(", ") : "(empty)";
}
