CREATE OR REPLACE FUNCTION catalog.schema_table(p_schema text, p_table text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_object(
    'schema', p_schema,
    'table', p_table,
    'comment', (
      SELECT d.description FROM pg_description d
      JOIN pg_class c ON c.oid = d.objoid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = p_schema AND c.relname = p_table AND d.objsubid = 0
    ),
    'columns', (
      SELECT coalesce(jsonb_agg(
        jsonb_build_object(
          'name', col.column_name,
          'type', col.udt_name || CASE
            WHEN col.character_maximum_length IS NOT NULL THEN '(' || col.character_maximum_length || ')'
            ELSE '' END,
          'nullable', col.is_nullable = 'YES',
          'default', col.column_default,
          'comment', (
            SELECT d.description FROM pg_description d
            JOIN pg_class c ON c.oid = d.objoid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = d.objsubid
            WHERE n.nspname = p_schema AND c.relname = p_table AND a.attname = col.column_name::name
          )
        ) ORDER BY col.ordinal_position
      ), '[]')
      FROM information_schema.columns col
      WHERE col.table_schema = p_schema AND col.table_name = p_table
    ),
    'check_constraints', (
      SELECT coalesce(jsonb_agg(
        jsonb_build_object(
          'name', cc.constraint_name,
          'definition', cc.check_clause
        )
      ), '[]')
      FROM information_schema.check_constraints cc
      JOIN information_schema.table_constraints tc
        ON tc.constraint_name = cc.constraint_name AND tc.constraint_schema = cc.constraint_schema
      WHERE tc.table_schema = p_schema AND tc.table_name = p_table
        AND tc.constraint_type = 'CHECK'
        AND cc.check_clause NOT LIKE '%IS NOT NULL%'
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
      WHERE tc.table_schema = p_schema AND tc.table_name = p_table
        AND tc.constraint_type = 'FOREIGN KEY'
    ),
    'indexes', (
      SELECT coalesce(jsonb_agg(
        jsonb_build_object(
          'name', i.relname,
          'unique', ix.indisunique,
          'columns', (
            SELECT jsonb_agg(a.attname ORDER BY k.ord)
            FROM unnest(ix.indkey) WITH ORDINALITY AS k(attnum, ord)
            JOIN pg_attribute a ON a.attrelid = ix.indrelid AND a.attnum = k.attnum
          )
        )
      ), '[]')
      FROM pg_index ix
      JOIN pg_class t ON t.oid = ix.indrelid
      JOIN pg_class i ON i.oid = ix.indexrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
      WHERE n.nspname = p_schema AND t.relname = p_table
        AND NOT ix.indisprimary
    ),
    'rls', (
      SELECT jsonb_build_object(
        'enabled', c.relrowsecurity,
        'policies', coalesce((
          SELECT jsonb_agg(jsonb_build_object('name', pol.polname, 'permissive', pol.polpermissive))
          FROM pg_policy pol WHERE pol.polrelid = c.oid
        ), '[]')
      )
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = p_schema AND c.relname = p_table
    )
  );
$function$;
