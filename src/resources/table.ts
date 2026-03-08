import type { DbClient } from "../connection.js";

export interface TableDetail {
  name: string;
  schema: string;
  columns: ColumnInfo[];
  indexes: string[];
  used_by: { name: string; mode: "R" | "W" | "RW" }[];
}

export interface ColumnInfo {
  name: string;
  type: string;
  nullable: boolean;
  default_value: string | null;
  is_pk: boolean;
  fk_target: string | null;
}

// --- Query ---

export async function queryTable(client: DbClient, schema: string, name: string): Promise<TableDetail | null> {
  const { rows: colRows } = await client.query<{
    attname: string;
    typname: string;
    attnotnull: boolean;
    default_val: string | null;
    is_pk: boolean;
    fk_target: string | null;
  }>(`
    SELECT
      a.attname,
      pg_catalog.format_type(a.atttypid, a.atttypmod) AS typname,
      a.attnotnull,
      pg_get_expr(d.adbin, d.adrelid) AS default_val,
      COALESCE((
        SELECT true FROM pg_index i
        WHERE i.indrelid = c.oid AND i.indisprimary AND a.attnum = ANY(i.indkey)
      ), false) AS is_pk,
      (
        SELECT fn.nspname || '.' || fc.relname || '.' || fa.attname
        FROM pg_constraint con
        JOIN pg_class fc ON fc.oid = con.confrelid
        JOIN pg_namespace fn ON fn.oid = fc.relnamespace
        JOIN pg_attribute fa ON fa.attrelid = con.confrelid AND fa.attnum = con.confkey[1]
        WHERE con.conrelid = c.oid AND con.contype = 'f' AND a.attnum = con.conkey[1]
        LIMIT 1
      ) AS fk_target
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    LEFT JOIN pg_attrdef d ON d.adrelid = c.oid AND d.adnum = a.attnum
    WHERE n.nspname = $1 AND c.relname = $2
    ORDER BY a.attnum
  `, [schema, name]);

  if (colRows.length === 0) return null;

  const columns: ColumnInfo[] = colRows.map((r) => ({
    name: r.attname,
    type: r.typname,
    nullable: !r.attnotnull,
    default_value: r.default_val,
    is_pk: r.is_pk,
    fk_target: r.fk_target,
  }));

  const { rows: idxRows } = await client.query<{ indexname: string; indexdef: string }>(`
    SELECT indexname, indexdef FROM pg_indexes
    WHERE schemaname = $1 AND tablename = $2 AND indexname NOT LIKE '%_pkey'
  `, [schema, name]);
  const indexes = idxRows.map((r) => r.indexname);

  const used_by = await findTableUsers(client, schema, name);

  return { name, schema, columns, indexes, used_by };
}

async function findTableUsers(
  client: DbClient,
  schema: string,
  tableName: string,
): Promise<{ name: string; mode: "R" | "W" | "RW" }[]> {
  const { rows } = await client.query<{ proname: string; prosrc: string }>(`
    SELECT p.proname, p.prosrc
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_language l ON l.oid = p.prolang
    WHERE n.nspname = $1 AND l.lanname = 'plpgsql'
      AND p.prosrc ~* $2
  `, [schema, `\\m${tableName}\\M`]);

  const esc = tableName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return rows.map((r) => {
    const hasWrite = new RegExp(`(INSERT\\s+INTO|UPDATE|DELETE\\s+FROM)\\s+.*\\b${esc}\\b`, "i").test(r.prosrc);
    const hasRead = new RegExp(`(FROM|JOIN)\\s+.*\\b${esc}\\b`, "i").test(r.prosrc);
    const mode: "R" | "W" | "RW" = hasWrite && hasRead ? "RW" : hasWrite ? "W" : "R";
    return { name: r.proname, mode };
  });
}

// --- Format ---

export function formatTable(table: TableDetail): string {
  const parts: string[] = [];
  parts.push(`${table.schema}.${table.name}`);

  const nameW = Math.max(...table.columns.map((c) => c.name.length));
  const typeW = Math.max(...table.columns.map((c) => c.type.length));

  for (const col of table.columns) {
    let suffix = "";
    if (col.is_pk) suffix += " PK";
    if (col.fk_target) suffix += ` FK -> ${col.fk_target}`;
    if (!col.nullable && !col.is_pk) suffix += " NOT NULL";
    if (col.default_value) suffix += ` DEFAULT ${col.default_value}`;
    parts.push(`  ${col.name.padEnd(nameW + 2)}${col.type.padEnd(typeW + 2)}${suffix}`);
  }

  parts.push(table.indexes.length > 0
    ? `  indexes: ${table.indexes.join(", ")}`
    : `  indexes: none`);
  parts.push(table.used_by.length > 0
    ? `  used_by: ${table.used_by.map((u) => `${u.name}(${u.mode})`).join(", ")}`
    : `  used_by: none`);

  return parts.join("\n");
}
