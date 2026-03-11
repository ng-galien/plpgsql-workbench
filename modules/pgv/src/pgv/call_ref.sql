CREATE OR REPLACE FUNCTION pgv.call_ref(p_fname text, p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_schema text;
  v_path text;
  v_qs text := '';
  v_key text;
  v_val text;
BEGIN
  -- Get current schema from route context
  v_schema := trim(LEADING '/' FROM coalesce(current_setting('pgv.route_prefix', true), ''));

  -- Verify function exists in pg_proc
  IF v_schema <> '' THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = v_schema AND p.proname = p_fname AND p.prokind = 'f'
    ) THEN
      RAISE EXCEPTION 'pgv.call_ref: function %.% not found', v_schema, p_fname
        USING HINT = 'Check that the function exists in schema ' || v_schema;
    END IF;
  END IF;

  -- Derive path from function name: get_drawing → /drawing, get_index → /
  v_path := regexp_replace(p_fname, '^(get|post)_', '');
  IF v_path = 'index' THEN
    v_path := '/';
  ELSE
    v_path := '/' || v_path;
  END IF;

  -- Build query string from params
  FOR v_key, v_val IN SELECT k, v FROM jsonb_each_text(p_params) AS x(k, v)
  LOOP
    IF v_qs = '' THEN
      v_qs := '?' || v_key || '=' || v_val;
    ELSE
      v_qs := v_qs || '&' || v_key || '=' || v_val;
    END IF;
  END LOOP;

  -- Build full URL with schema prefix
  IF v_schema <> '' THEN
    RETURN '/' || v_schema || v_path || v_qs;
  ELSE
    RETURN v_path || v_qs;
  END IF;
END;
$function$;
