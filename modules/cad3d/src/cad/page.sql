CREATE OR REPLACE FUNCTION cad.page(p_path text, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_path text;
  v_params jsonb;
  v_kv text;
  v_pair text[];
BEGIN
  -- Split path and query string (app mode sends path?params as p_path)
  v_path := split_part(COALESCE(p_path, '/'), '?', 1);
  v_params := p_body;

  IF p_path LIKE '%?%' THEN
    FOR v_kv IN SELECT unnest(string_to_array(split_part(p_path, '?', 2), '&'))
    LOOP
      v_pair := string_to_array(v_kv, '=');
      v_params := v_params || jsonb_build_object(v_pair[1], v_pair[2]);
    END LOOP;
  END IF;

  RETURN pgv.route('cad', v_path, 'GET', v_params);
END;
$function$;
