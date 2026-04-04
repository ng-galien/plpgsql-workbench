CREATE OR REPLACE FUNCTION pgv.schema_comments(p_schema text)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  WITH schema_comment AS (
    SELECT 'SCHEMA ' || p_schema || ': ' || coalesce(d.description, '(none)')
    FROM pg_namespace n
    LEFT JOIN pg_description d ON d.objoid = n.oid AND d.classoid = 'pg_namespace'::regclass
    WHERE n.nspname = p_schema
  ),
  table_comments AS (
    SELECT c.relname AS tbl,
           d.description AS tbl_comment,
           a.attname AS col,
           cd.description AS col_comment
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    LEFT JOIN pg_description d ON d.objoid = c.oid AND d.objsubid = 0
    LEFT JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    LEFT JOIN pg_description cd ON cd.objoid = c.oid AND cd.objsubid = a.attnum
    WHERE n.nspname = p_schema AND c.relkind = 'r'
    ORDER BY c.relname, a.attnum
  ),
  formatted AS (
    SELECT string_agg(line, chr(10)) AS body
    FROM (
      SELECT '## ' || tbl
        || chr(10) || 'table: ' || coalesce(tbl_comment, '(no comment)')
        || chr(10) || string_agg(
          '  ' || col || ': ' || coalesce(col_comment, '-'),
          chr(10) ORDER BY col
        ) AS line
      FROM table_comments
      GROUP BY tbl, tbl_comment
      ORDER BY tbl
    ) sub
  )
  SELECT (SELECT * FROM schema_comment) || chr(10) || chr(10) || coalesce(f.body, '(no tables)')
  FROM formatted f;
$function$;
