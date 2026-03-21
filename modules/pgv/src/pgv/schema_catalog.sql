CREATE OR REPLACE FUNCTION pgv.schema_catalog()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT coalesce(jsonb_agg(row ORDER BY row->>'schema'), '[]')
  FROM (
    SELECT jsonb_build_object(
      'schema', n.nspname,
      'comment', d.description,
      'tables', (
        SELECT count(*) FROM pg_class c
        WHERE c.relnamespace = n.oid AND c.relkind = 'r'
      ),
      'functions', (
        SELECT count(*) FROM pg_proc p
        WHERE p.pronamespace = n.oid
      )
    ) AS row
    FROM pg_namespace n
    LEFT JOIN pg_description d ON d.objoid = n.oid AND d.classoid = 'pg_namespace'::regclass
    WHERE n.nspname NOT LIKE 'pg_%'
      AND n.nspname NOT IN ('information_schema', 'public', 'extensions')
      AND n.nspname NOT LIKE '%_ut'
      AND n.nspname NOT LIKE '%_qa'
      AND n.nspname NOT LIKE '%_it'
  ) sub;
$function$;
