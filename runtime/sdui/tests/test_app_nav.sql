CREATE OR REPLACE FUNCTION sdui_ut.test_app_nav()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_mod jsonb;
BEGIN
  -- Call app_nav
  v_result := sdui.app_nav();

  -- Returns a jsonb array
  RETURN NEXT ok(jsonb_typeof(v_result) = 'array', 'returns jsonb array');

  -- At least one module (tenant_module has active entries)
  RETURN NEXT ok(jsonb_array_length(v_result) > 0, 'at least one module');

  -- sdui excluded
  RETURN NEXT ok(
    NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_result) e WHERE e->>'module' = 'sdui'),
    'sdui excluded from results'
  );

  -- Each module has required keys
  FOR v_mod IN SELECT * FROM jsonb_array_elements(v_result) LOOP
    RETURN NEXT ok(v_mod ? 'module', 'module key present: ' || (v_mod->>'module'));
    RETURN NEXT ok(v_mod ? 'brand', 'brand key present: ' || (v_mod->>'module'));
    RETURN NEXT ok(v_mod ? 'schema', 'schema key present: ' || (v_mod->>'module'));
    RETURN NEXT ok(v_mod ? 'items', 'items key present: ' || (v_mod->>'module'));
    RETURN NEXT ok(jsonb_typeof(v_mod->'items') = 'array', 'items is array: ' || (v_mod->>'module'));
    EXIT; -- check first module only
  END LOOP;
END;
$function$;
