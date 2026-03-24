CREATE OR REPLACE FUNCTION pgv.check_view(p_schema text, p_entity text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_fn text := p_entity || '_view';
  v_result jsonb;
  v_valid boolean;
BEGIN
  -- Check function exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = p_schema AND p.proname = v_fn
  ) THEN
    RETURN jsonb_build_object('valid', false, 'errors', jsonb_build_array('function ' || p_schema || '.' || v_fn || '() does not exist'));
  END IF;

  -- Call the view function
  EXECUTE format('SELECT %I.%I()', p_schema, v_fn) INTO v_result;

  -- Validate against JSON Schema
  v_valid := jsonb_matches_schema(pgv.view_schema(), v_result);

  IF v_valid THEN
    RETURN jsonb_build_object('valid', true, 'uri', v_result->>'uri');
  ELSE
    RETURN jsonb_build_object('valid', false, 'errors', jsonb_build_array('JSON Schema validation failed'), 'result', v_result);
  END IF;
END;
$function$;
