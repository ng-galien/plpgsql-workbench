CREATE OR REPLACE FUNCTION catalog.schema_inspect(p_schema text, p_entity text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_out text := '';
  v_table_oid oid;
  v_table_comment text;
  v_rec record;
  v_pk_cols text[];
  v_fk_cols text[];
  v_crud_names text[] := ARRAY[
    p_entity || '_create', p_entity || '_read', p_entity || '_load',
    p_entity || '_list', p_entity || '_update', p_entity || '_delete'
  ];
  v_has_section boolean;
  v_type_display text;
  v_flags text;
BEGIN
  -- Resolve table OID
  SELECT c.oid, d.description INTO v_table_oid, v_table_comment
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  LEFT JOIN pg_description d ON d.objoid = c.oid AND d.objsubid = 0
  WHERE n.nspname = p_schema AND c.relname = p_entity AND c.relkind = 'r';

  IF v_table_oid IS NULL THEN
    RETURN format('entity %I.%I not found', p_schema, p_entity);
  END IF;

  -- Header
  v_out := '## ' || p_entity || chr(10);
  IF v_table_comment IS NOT NULL THEN
    v_out := v_out || v_table_comment || chr(10);
  END IF;

  -- Get PK columns
  SELECT array_agg(a.attname) INTO v_pk_cols
  FROM pg_index ix
  JOIN pg_attribute a ON a.attrelid = ix.indrelid AND a.attnum = ANY(ix.indkey)
  WHERE ix.indrelid = v_table_oid AND ix.indisprimary;

  -- Get FK columns
  SELECT array_agg(a.attname) INTO v_fk_cols
  FROM pg_constraint con
  JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = ANY(con.conkey)
  WHERE con.conrelid = v_table_oid AND con.contype = 'f';

  -- Attributes section
  v_out := v_out || chr(10) || 'attributes:' || chr(10);
  FOR v_rec IN
    SELECT a.attname, t.typname, a.attnotnull, d.description
    FROM pg_attribute a
    JOIN pg_type t ON t.oid = a.atttypid
    LEFT JOIN pg_description d ON d.objoid = v_table_oid AND d.objsubid = a.attnum
    WHERE a.attrelid = v_table_oid AND a.attnum > 0 AND NOT a.attisdropped
    ORDER BY
      CASE WHEN a.attname = ANY(coalesce(v_pk_cols, '{}')) THEN 0
           WHEN a.attname = ANY(coalesce(v_fk_cols, '{}')) THEN 1
           WHEN a.attnotnull THEN 2
           ELSE 3 END,
      a.attnum
  LOOP
    -- Format type
    v_type_display := v_rec.typname;
    IF v_type_display LIKE '\_%' THEN
      v_type_display := substr(v_type_display, 2) || '[]';
    END IF;

    -- Flags
    v_flags := '';
    IF v_rec.attname = ANY(coalesce(v_pk_cols, '{}')) THEN
      v_flags := 'PK';
    ELSIF v_rec.attname = ANY(coalesce(v_fk_cols, '{}')) THEN
      v_flags := 'FK';
    ELSIF v_rec.attnotnull THEN
      v_flags := 'NOT NULL';
    END IF;

    v_out := v_out || '  ' || rpad(v_rec.attname, 22) || rpad(v_type_display, 14) || rpad(v_flags, 10);
    IF v_rec.description IS NOT NULL THEN
      v_out := v_out || v_rec.description;
    END IF;
    v_out := v_out || chr(10);
  END LOOP;

  -- CRUD section
  v_has_section := false;
  FOR v_rec IN
    SELECT p.proname, pg_get_function_arguments(p.oid) AS args,
           t.typname AS rettype, d.description,
           p.proretset
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_type t ON t.oid = p.prorettype
    LEFT JOIN pg_description d ON d.objoid = p.oid
    WHERE n.nspname = p_schema
      AND p.proname IN (
        p_entity || '_create', p_entity || '_read', p_entity || '_load',
        p_entity || '_list', p_entity || '_update', p_entity || '_delete'
      )
      AND p.proconfig @> ARRAY['api.expose=mcp']
    ORDER BY array_position(v_crud_names, p.proname)
  LOOP
    IF NOT v_has_section THEN
      v_out := v_out || chr(10) || 'crud:' || chr(10);
      v_has_section := true;
    END IF;
    v_out := v_out || '  ' || v_rec.proname || '(' || coalesce(v_rec.args, '') || ')';
    IF v_rec.proretset THEN
      v_out := v_out || ' -> SETOF ' || v_rec.rettype;
    ELSE
      v_out := v_out || ' -> ' || v_rec.rettype;
    END IF;
    IF v_rec.description IS NOT NULL THEN
      v_out := v_out || '  — ' || v_rec.description;
    END IF;
    v_out := v_out || chr(10);
  END LOOP;

  -- Methods section
  v_has_section := false;
  FOR v_rec IN
    SELECT p.proname, pg_get_function_arguments(p.oid) AS args,
           t.typname AS rettype, d.description,
           p.proretset
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_type t ON t.oid = p.prorettype
    LEFT JOIN pg_description d ON d.objoid = p.oid
    WHERE n.nspname = p_schema
      AND p.proname LIKE p_entity || '_%'
      AND p.proname NOT IN (
        p_entity || '_create', p_entity || '_read', p_entity || '_load',
        p_entity || '_list', p_entity || '_update', p_entity || '_delete'
      )
      AND p.proconfig @> ARRAY['api.expose=mcp']
    ORDER BY p.proname
  LOOP
    IF NOT v_has_section THEN
      v_out := v_out || chr(10) || 'methods:' || chr(10);
      v_has_section := true;
    END IF;
    v_out := v_out || '  ' || v_rec.proname || '(' || coalesce(v_rec.args, '') || ')';
    IF v_rec.proretset THEN
      v_out := v_out || ' -> SETOF ' || v_rec.rettype;
    ELSE
      v_out := v_out || ' -> ' || v_rec.rettype;
    END IF;
    IF v_rec.description IS NOT NULL THEN
      v_out := v_out || '  — ' || v_rec.description;
    END IF;
    v_out := v_out || chr(10);
  END LOOP;

  -- Relations section (incoming FK)
  v_has_section := false;
  FOR v_rec IN
    SELECT c1.relname AS source_table, a1.attname AS source_col, d.description
    FROM pg_constraint con
    JOIN pg_class c1 ON c1.oid = con.conrelid
    JOIN pg_attribute a1 ON a1.attrelid = con.conrelid AND a1.attnum = con.conkey[1]
    LEFT JOIN pg_description d ON d.objoid = c1.oid AND d.objsubid = 0
    WHERE con.confrelid = v_table_oid AND con.contype = 'f'
    ORDER BY c1.relname
  LOOP
    IF NOT v_has_section THEN
      v_out := v_out || chr(10) || 'relations:' || chr(10);
      v_has_section := true;
    END IF;
    v_out := v_out || '  ' || v_rec.source_table || ' -> ' || v_rec.source_col || ' FK';
    IF v_rec.description IS NOT NULL THEN
      v_out := v_out || '  — ' || v_rec.description;
    END IF;
    v_out := v_out || chr(10);
  END LOOP;

  RETURN v_out;
END;
$function$;
