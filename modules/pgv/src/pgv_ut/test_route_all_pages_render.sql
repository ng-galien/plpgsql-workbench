CREATE OR REPLACE FUNCTION pgv_ut.test_route_all_pages_render()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_item jsonb;
  v_href text;
  v_html text;
BEGIN
  FOR v_item IN SELECT * FROM jsonb_array_elements(pgv_qa.nav_items()) LOOP
    v_href := v_item->>'href';
    v_html := pgv.route('pgv_qa', v_href);
    RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 0,
      format('route pgv_qa %s renders HTML', v_href));
    RETURN NEXT ok(v_html LIKE '%<nav%',
      format('route pgv_qa %s has nav', v_href));
    RETURN NEXT ok(v_html LIKE '%<main%',
      format('route pgv_qa %s has main', v_href));
  END LOOP;
END;
$function$;
