CREATE OR REPLACE FUNCTION pgv_ut.test_breadcrumb()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  PERFORM set_config('pgv.route_prefix', '/pgv_qa', true);
  v_html := pgv.breadcrumb('Home', '/pgv_qa/', 'Page', '/pgv_qa/page', 'Current');
  RETURN NEXT ok(v_html LIKE '%pgv-breadcrumb%', 'breadcrumb has class');
  RETURN NEXT ok(v_html LIKE '%<a href="/pgv_qa/">Home</a>%', 'breadcrumb first item is link');
  RETURN NEXT ok(v_html LIKE '%>Current<%', 'breadcrumb last item is text');
  RETURN NEXT ok(v_html LIKE '%<li>Current</li>%', 'breadcrumb last item is plain li');
END;
$function$;
