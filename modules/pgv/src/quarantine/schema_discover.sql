CREATE OR REPLACE FUNCTION pgv.schema_discover(p_schema text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT coalesce(jsonb_agg(tbl ORDER BY tbl->>'table'), '[]')
  FROM (
    SELECT jsonb_build_object(
      'table', c.relname,
      'comment', d.description,
      'rows', c.reltuples::bigint,
      'columns', (
        SELECT coalesce(jsonb_agg(
          jsonb_build_object(
            'name', col.column_name,
            'type', col.udt_name || CASE
              WHEN col.character_maximum_length IS NOT NULL THEN '(' || col.character_maximum_length || ')'
              ELSE '' END,
            'nullable', col.is_nullable = 'YES',
            'default', col.column_default,
            'comment', cd.description
          ) ORDER BY col.ordinal_position
        ), '[]')
        FROM information_schema.columns col
        LEFT JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = col.column_name::name
        LEFT JOIN pg_description cd ON cd.objoid = c.oid AND cd.objsubid = a.attnum
        WHERE col.table_schema = p_schema AND col.table_name = c.relname
      ),
      'foreign_keys', (
        SELECT coalesce(jsonb_agg(
          jsonb_build_object(
            'column', kcu.column_name,
            'references', ccu.table_schema || '.' || ccu.table_name || '.' || ccu.column_name
          )
        ), '[]')
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
        JOIN information_schema.constraint_column_usage ccu
          ON ccu.constraint_name = tc.constraint_name AND ccu.constraint_schema = tc.constraint_schema
        WHERE tc.table_schema = p_schema AND tc.table_name = c.relname
          AND tc.constraint_type = 'FOREIGN KEY'
      )
    ) AS tbl
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    LEFT JOIN pg_description d ON d.objoid = c.oid AND d.objsubid = 0
    WHERE n.nspname = p_schema AND c.relkind = 'r'
  ) sub;
$function$;
