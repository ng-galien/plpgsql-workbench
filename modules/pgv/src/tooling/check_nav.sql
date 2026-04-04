CREATE OR REPLACE FUNCTION pgv.check_nav()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_nav jsonb;
  v_mod jsonb;
  v_out text := 'check_nav:' || chr(10) || chr(10);
  v_ok int := 0;
  v_err int := 0;
BEGIN
  v_nav := pgv.app_nav();

  FOR v_mod IN SELECT * FROM jsonb_array_elements(v_nav) LOOP
    IF jsonb_matches_schema(pgv.nav_schema(), v_mod) THEN
      v_out := v_out || '✓ ' || (v_mod->>'module') || chr(10);
      v_ok := v_ok + 1;
    ELSE
      v_out := v_out || '✗ ' || (v_mod->>'module') || ' — schema validation failed' || chr(10);
      v_err := v_err + 1;
    END IF;
  END LOOP;

  v_out := v_out || chr(10);
  IF v_err = 0 THEN
    v_out := v_out || 'ok (' || v_ok || ' modules)';
  ELSE
    v_out := v_out || v_err || ' error(s), ' || v_ok || ' ok';
  END IF;

  RETURN v_out;
END;
$function$;
