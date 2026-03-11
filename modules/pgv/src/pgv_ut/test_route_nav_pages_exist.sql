CREATE OR REPLACE FUNCTION pgv_ut.test_route_nav_pages_exist()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_schema text := 'pgv_qa';
  v_item jsonb;
  v_href text;
  v_fname text;
BEGIN
  FOR v_item IN SELECT * FROM jsonb_array_elements(pgv_qa.nav_items()) LOOP
    v_href := v_item->>'href';
    IF v_href = '/' THEN
      v_fname := 'page_index';
    ELSE
      v_fname := 'page_' || replace(replace(trim(BOTH '/' FROM v_href), '/', '_'), '-', '_');
    END IF;
    RETURN NEXT ok(
      EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = v_schema AND p.proname = v_fname),
      format('nav %s -> %s.%s() exists', v_href, v_schema, v_fname)
    );
  END LOOP;
END;
$function$;
