import type { DbClient } from "../connection.js";

export interface TriggerDetail {
  name: string;
  schema: string;
  table: string;
  event: string;
  function: string;
  for_each: string;
}

// --- Query ---

export async function queryTrigger(client: DbClient, schema: string, name: string): Promise<TriggerDetail | null> {
  const { rows } = await client.query<{
    table_name: string;
    event: string;
    function_name: string;
    for_each: string;
  }>(
    `
    SELECT
      c.relname AS table_name,
      string_agg(em.event, ' OR ') AS event,
      p.proname AS function_name,
      CASE WHEN t.tgtype & 1 = 1 THEN 'ROW' ELSE 'STATEMENT' END AS for_each
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_proc p ON p.oid = t.tgfoid
    CROSS JOIN LATERAL (
      VALUES
        (CASE WHEN t.tgtype & 4 = 4 THEN 'INSERT' END),
        (CASE WHEN t.tgtype & 8 = 8 THEN 'DELETE' END),
        (CASE WHEN t.tgtype & 16 = 16 THEN 'UPDATE' END),
        (CASE WHEN t.tgtype & 32 = 32 THEN 'TRUNCATE' END)
    ) AS em(event)
    WHERE n.nspname = $1 AND t.tgname = $2 AND NOT t.tgisinternal AND em.event IS NOT NULL
    GROUP BY t.tgname, c.relname, p.proname, t.tgtype
    LIMIT 1
  `,
    [schema, name],
  );

  if (rows.length === 0) return null;

  const row = rows[0]!;
  return {
    name,
    schema,
    table: row.table_name,
    event: row.event,
    function: row.function_name,
    for_each: row.for_each,
  };
}

// --- Format ---

export function formatTrigger(trigger: TriggerDetail): string {
  return [
    `${trigger.schema}.${trigger.name}`,
    `  table: ${trigger.schema}.${trigger.table}`,
    `  event: ${trigger.event}`,
    `  function: ${trigger.schema}.${trigger.function}()`,
    `  for_each: ${trigger.for_each}`,
  ].join("\n");
}
