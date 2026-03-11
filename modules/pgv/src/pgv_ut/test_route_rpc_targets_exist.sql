CREATE OR REPLACE FUNCTION pgv_ut.test_route_rpc_targets_exist()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_schema text := 'pgv_qa';
  v_item jsonb;
  v_href text;
  v_html text;
  v_rpc text;
BEGIN
  FOR v_item IN SELECT * FROM jsonb_array_elements(pgv_qa.nav_items()) LOOP
    v_href := v_item->>'href';
    v_html := pgv.route(v_schema, v_href, 'GET');
    -- Extract all data-rpc="xxx" values
    FOR v_rpc IN
      SELECT (regexp_matches(v_html, 'data-rpc="([^"]+)"', 'g'))[1]
    LOOP
      RETURN NEXT ok(
        EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = v_schema AND p.proname = v_rpc),
        format('data-rpc="%s" on %s -> %s.%s() exists', v_rpc, v_href, v_schema, v_rpc)
      );
    END LOOP;
  END LOOP;
END;
$function$;
