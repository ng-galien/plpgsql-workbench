CREATE OR REPLACE FUNCTION pgv.app_nav()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb := '[]'::jsonb;
  v_mod record;
  v_schema text;
  v_brand text;
  v_items jsonb;
BEGIN
  FOR v_mod IN
    SELECT tm.module
      FROM workbench.tenant_module tm
     WHERE tm.active = true
       AND tm.module <> 'pgv'
     ORDER BY tm.sort_order, tm.module
  LOOP
    -- Resolve schema: find the namespace that has nav_items()
    SELECT n.nspname INTO v_schema
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE p.proname = 'nav_items'
       AND n.nspname NOT LIKE '%\_qa' ESCAPE '\'
       AND n.nspname NOT LIKE '%\_ut' ESCAPE '\'
       AND n.nspname <> 'pgv'
       AND (n.nspname = v_mod.module OR v_mod.module LIKE n.nspname || '%')
     ORDER BY
       CASE WHEN n.nspname = v_mod.module THEN 0 ELSE 1 END
     LIMIT 1;

    IF v_schema IS NULL THEN
      CONTINUE;
    END IF;

    -- Get brand
    BEGIN
      EXECUTE format('SELECT %I.brand()', v_schema) INTO v_brand;
    EXCEPTION WHEN OTHERS THEN
      v_brand := initcap(v_mod.module);
    END;

    -- Get nav_items (handle both jsonb and TABLE return)
    BEGIN
      EXECUTE format('SELECT %I.nav_items()', v_schema) INTO v_items;
    EXCEPTION WHEN OTHERS THEN
      BEGIN
        EXECUTE format(
          'SELECT jsonb_agg(jsonb_build_object(''href'', href, ''label'', label, ''icon'', icon)) FROM %I.nav_items()',
          v_schema
        ) INTO v_items;
      EXCEPTION WHEN OTHERS THEN
        v_items := '[]'::jsonb;
      END;
    END;

    v_result := v_result || jsonb_build_object(
      'module', v_mod.module,
      'brand', v_brand,
      'schema', v_schema,
      'items', coalesce(v_items, '[]'::jsonb)
    );
  END LOOP;

  RETURN v_result;
END;
$function$;
