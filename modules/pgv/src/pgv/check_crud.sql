CREATE OR REPLACE FUNCTION pgv.check_crud(p_schema text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_out text := 'check_crud: ' || p_schema || chr(10) || chr(10);
  v_rec record;
  v_entity text;
  v_has_create boolean;
  v_has_read boolean;
  v_has_list boolean;
  v_has_update boolean;
  v_has_delete boolean;
  v_errors int := 0;
  v_warnings int := 0;
  v_ok_count int := 0;
  v_crud_count int := 0;
  v_line text;
  v_issues text[];
  v_fn_rec record;
BEGIN
  -- 1. Check overloads (same proname, multiple entries)
  FOR v_rec IN
    SELECT p.proname, count(*) AS cnt
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = p_schema
    GROUP BY p.proname
    HAVING count(*) > 1
    ORDER BY p.proname
  LOOP
    v_out := v_out || '✗ overload: ' || v_rec.proname || ' (' || v_rec.cnt || ' versions)' || chr(10);
    v_errors := v_errors + 1;
  END LOOP;

  -- 2. Naming warnings (_load, _get, _find, _insert, _remove)
  FOR v_rec IN
    SELECT p.proname
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = p_schema
      AND (p.proname LIKE '%_load' OR p.proname LIKE '%_get'
        OR p.proname LIKE '%_find' OR p.proname LIKE '%_insert'
        OR p.proname LIKE '%_remove')
    ORDER BY p.proname
  LOOP
    v_out := v_out || '⚠ naming: ' || v_rec.proname || ' — consider renaming to CRUD convention (_create/_read/_list/_update/_delete)' || chr(10);
    v_warnings := v_warnings + 1;
  END LOOP;

  -- 3. Per-entity CRUD analysis
  -- Discover entities from table names
  FOR v_rec IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = p_schema AND c.relkind = 'r'
    ORDER BY c.relname
  LOOP
    v_entity := v_rec.relname;
    v_issues := '{}';

    -- Check which CRUD functions exist
    SELECT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = p_schema AND p.proname = v_entity || '_create') INTO v_has_create;
    SELECT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = p_schema AND (p.proname = v_entity || '_read' OR p.proname = v_entity || '_load')) INTO v_has_read;
    SELECT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = p_schema AND p.proname = v_entity || '_list') INTO v_has_list;
    SELECT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = p_schema AND p.proname = v_entity || '_update') INTO v_has_update;
    SELECT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = p_schema AND p.proname = v_entity || '_delete') INTO v_has_delete;

    IF NOT v_has_create AND NOT v_has_read AND NOT v_has_list AND NOT v_has_delete THEN
      v_out := v_out || '⚠ ' || v_entity || ' — no CRUD functions' || chr(10);
      v_warnings := v_warnings + 1;
      CONTINUE;
    END IF;

    -- Build status line
    v_line := '';
    IF v_has_create THEN v_line := v_line || 'create '; v_crud_count := v_crud_count + 1; END IF;
    IF v_has_read THEN v_line := v_line || 'read '; v_crud_count := v_crud_count + 1; END IF;
    IF v_has_list THEN v_line := v_line || 'list '; v_crud_count := v_crud_count + 1; END IF;
    IF v_has_update THEN v_line := v_line || 'update '; v_crud_count := v_crud_count + 1; END IF;
    IF v_has_delete THEN v_line := v_line || 'delete '; v_crud_count := v_crud_count + 1; END IF;

    -- Check return types
    FOR v_fn_rec IN
      SELECT p.proname, t.typname AS rettype, p.proretset
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      JOIN pg_type t ON t.oid = p.prorettype
      WHERE n.nspname = p_schema
        AND p.proname IN (
          v_entity || '_create', v_entity || '_read', v_entity || '_load',
          v_entity || '_list', v_entity || '_update', v_entity || '_delete'
        )
    LOOP
      IF v_fn_rec.proname LIKE '%_delete' AND v_fn_rec.rettype != 'bool' THEN
        v_issues := v_issues || (v_fn_rec.proname || ' should return bool, returns ' || v_fn_rec.rettype);
        v_errors := v_errors + 1;
      END IF;
    END LOOP;

    IF array_length(v_issues, 1) > 0 THEN
      v_out := v_out || '✗ ' || v_entity || ' — ' || trim(v_line) || ' | ' || array_to_string(v_issues, '; ') || chr(10);
    ELSE
      v_out := v_out || '✓ ' || v_entity || ' — ' || trim(v_line) || chr(10);
      v_ok_count := v_ok_count + 1;
    END IF;
  END LOOP;

  -- Summary
  v_out := v_out || chr(10);
  IF v_errors = 0 AND v_warnings = 0 THEN
    v_out := v_out || 'ok (' || v_ok_count || ' entities, ' || v_crud_count || ' CRUD functions)';
  ELSE
    IF v_errors > 0 THEN v_out := v_out || v_errors || ' error(s)'; END IF;
    IF v_warnings > 0 THEN
      IF v_errors > 0 THEN v_out := v_out || ', '; END IF;
      v_out := v_out || v_warnings || ' warning(s)';
    END IF;
  END IF;

  RETURN v_out;
END;
$function$;
