CREATE OR REPLACE FUNCTION pgv.ui_form_for(p_schema text, p_entity text, p_verb text DEFAULT 'set'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_fields jsonb[] := '{}';
  v_rec record;
  v_field_type text;
  v_label text;
  v_required boolean;
  v_options jsonb;
  v_skip text[] := ARRAY['id', 'tenant_id', 'created_at', 'updated_at', 'slug', 'search_vec'];
BEGIN
  FOR v_rec IN
    SELECT a.attname, t.typname, a.attnotnull,
           d.description AS col_comment,
           -- FK info
           (SELECT n2.nspname FROM pg_constraint con
            JOIN pg_class c2 ON c2.oid = con.confrelid
            JOIN pg_namespace n2 ON n2.oid = c2.relnamespace
            WHERE con.conrelid = c.oid AND con.contype = 'f'
              AND a.attnum = ANY(con.conkey)
            LIMIT 1) AS fk_schema,
           (SELECT c2.relname FROM pg_constraint con
            JOIN pg_class c2 ON c2.oid = con.confrelid
            WHERE con.conrelid = c.oid AND con.contype = 'f'
              AND a.attnum = ANY(con.conkey)
            LIMIT 1) AS fk_table
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_type t ON t.oid = a.atttypid
    LEFT JOIN pg_description d ON d.objoid = c.oid AND d.objsubid = a.attnum
    WHERE n.nspname = p_schema AND c.relname = p_entity
      AND a.attnum > 0 AND NOT a.attisdropped
      AND a.attname != ALL(v_skip)
    ORDER BY a.attnum
  LOOP
    -- Map PG type to SDUI field type
    v_options := NULL;

    IF v_rec.fk_table IS NOT NULL THEN
      v_field_type := 'select';
      -- FK select: options loaded from datasource
      v_options := jsonb_build_object(
        'source', v_rec.fk_schema || '://' || v_rec.fk_table
      );
    ELSIF v_rec.typname IN ('int2', 'int4', 'int8', 'float4', 'float8', 'numeric') THEN
      v_field_type := 'number';
    ELSIF v_rec.typname = 'bool' THEN
      v_field_type := 'checkbox';
    ELSIF v_rec.typname IN ('timestamptz', 'timestamp', 'date') THEN
      v_field_type := 'date';
    ELSIF v_rec.typname = 'jsonb' THEN
      v_field_type := 'textarea';
    ELSIF v_rec.typname LIKE '\_text' OR v_rec.typname LIKE '\_%' THEN
      v_field_type := 'textarea';
    ELSE
      v_field_type := 'text';
    END IF;

    -- Label: COMMENT ON COLUMN or column name humanized
    v_label := coalesce(v_rec.col_comment, replace(v_rec.attname, '_', ' '));

    -- Required: NOT NULL and not a boolean (booleans default to false)
    v_required := v_rec.attnotnull AND v_rec.typname != 'bool';

    v_fields := v_fields || pgv.ui_field(v_rec.attname, v_field_type, v_label, v_required, v_options);
  END LOOP;

  RETURN pgv.ui_form(
    p_schema || '://' || p_entity,
    p_verb,
    array_to_json(v_fields)::jsonb
  );
END;
$function$;
