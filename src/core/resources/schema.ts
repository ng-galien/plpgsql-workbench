import type { DbClient } from "../connection.js";
import { PlUri } from "../uri.js";

export interface SchemaOverview {
  name: string;
  tables: { name: string; columns_inline: string }[];
  functions: { name: string; signature: string }[];
  triggers: { name: string; summary: string }[];
}

// --- Query ---

export async function querySchema(client: DbClient, schema: string): Promise<SchemaOverview> {
  const [tables, functions, triggers] = await Promise.all([
    queryTablesOverview(client, schema),
    queryFunctionsOverview(client, schema),
    queryTriggersOverview(client, schema),
  ]);
  return { name: schema, tables, functions, triggers };
}

async function queryTablesOverview(
  client: DbClient,
  schema: string,
): Promise<{ name: string; columns_inline: string }[]> {
  const { rows } = await client.query<{ table_name: string; columns_inline: string }>(`
    SELECT
      c.relname AS table_name,
      string_agg(
        a.attname || ' ' || pg_catalog.format_type(a.atttypid, a.atttypmod)
        || CASE WHEN EXISTS (
          SELECT 1 FROM pg_index i
          WHERE i.indrelid = c.oid AND i.indisprimary AND a.attnum = ANY(i.indkey)
        ) THEN ' PK' ELSE '' END
        || COALESCE((
          SELECT ' FK→' || fn.nspname || '.' || fc.relname || '.' || fa.attname
          FROM pg_constraint con
          JOIN pg_class fc ON fc.oid = con.confrelid
          JOIN pg_namespace fn ON fn.oid = fc.relnamespace
          JOIN pg_attribute fa ON fa.attrelid = con.confrelid AND fa.attnum = con.confkey[1]
          WHERE con.conrelid = c.oid AND con.contype = 'f'
            AND a.attnum = con.conkey[1]
          LIMIT 1
        ), ''),
        ', ' ORDER BY a.attnum
      ) AS columns_inline
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    WHERE n.nspname = $1 AND c.relkind = 'r'
    GROUP BY c.relname, c.oid
    ORDER BY c.relname
  `, [schema]);
  return rows.map((r) => ({ name: r.table_name, columns_inline: r.columns_inline }));
}

async function queryFunctionsOverview(
  client: DbClient,
  schema: string,
): Promise<{ name: string; signature: string }[]> {
  const { rows } = await client.query<{ name: string; signature: string }>(`
    SELECT
      p.proname AS name,
      p.proname || '(' ||
      COALESCE(
        pg_get_function_arguments(p.oid), ''
      ) || ') -> ' ||
      pg_get_function_result(p.oid) AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_language l ON l.oid = p.prolang
    WHERE n.nspname = $1 AND l.lanname IN ('sql', 'plpgsql')
    ORDER BY p.proname
  `, [schema]);
  return rows;
}

async function queryTriggersOverview(
  client: DbClient,
  schema: string,
): Promise<{ name: string; summary: string }[]> {
  const { rows } = await client.query<{ name: string; summary: string }>(`
    SELECT DISTINCT
      t.tgname AS name,
      t.tgname || ' ON ' || c.relname || ' ' ||
      CASE WHEN t.tgtype & 2 = 2 THEN 'BEFORE' ELSE 'AFTER' END || ' ' ||
      array_to_string(ARRAY[
        CASE WHEN t.tgtype & 4 = 4 THEN 'INSERT' END,
        CASE WHEN t.tgtype & 8 = 8 THEN 'DELETE' END,
        CASE WHEN t.tgtype & 16 = 16 THEN 'UPDATE' END
      ]::text[], ' OR ') ||
      ' -> ' || p.proname || '()'
      AS summary
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_proc p ON p.oid = t.tgfoid
    WHERE n.nspname = $1 AND NOT t.tgisinternal
    ORDER BY summary
  `, [schema]);
  return rows;
}

// --- Format ---

export function formatSchema(overview: SchemaOverview): string {
  const parts: string[] = [];
  const s = overview.name;

  if (overview.tables.length > 0) {
    parts.push("tables:");
    for (const t of overview.tables) {
      parts.push(`  ${t.name} (${t.columns_inline})  ${PlUri.table(s, t.name)}`);
    }
  } else {
    parts.push("tables: none");
  }

  if (overview.functions.length > 0) {
    parts.push("functions:");
    for (const f of overview.functions) {
      parts.push(`  ${f.signature}  ${PlUri.fn(s, f.name)}`);
    }
  } else {
    parts.push("functions: none");
  }

  if (overview.triggers.length > 0) {
    parts.push("triggers:");
    for (const tr of overview.triggers) {
      parts.push(`  ${tr.summary}  ${PlUri.trigger(s, tr.name)}`);
    }
  } else {
    parts.push("triggers: none");
  }

  return parts.join("\n");
}
