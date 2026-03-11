CREATE OR REPLACE FUNCTION pgv_ut.test_route_prefixes_nav()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  -- pgv_qa has nav_items with href="/atoms" etc.
  v_html := pgv.route('pgv_qa', '/');

  -- Nav links should be prefixed with /pgv_qa
  RETURN NEXT ok(v_html LIKE '%href="/pgv_qa/"%', 'nav dashboard href prefixed');
  RETURN NEXT ok(v_html LIKE '%href="/pgv_qa/atoms"%', 'nav atoms href prefixed');
  RETURN NEXT ok(v_html LIKE '%href="/pgv_qa/forms"%', 'nav forms href prefixed');

  -- route_prefix should be set for page functions
  RETURN NEXT is(current_setting('pgv.route_prefix', true), '/pgv_qa', 'route_prefix set after route call');
END;
$function$;
