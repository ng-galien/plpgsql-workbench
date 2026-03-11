CREATE OR REPLACE FUNCTION pgv_ut.test_page()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  PERFORM set_config('pgv.route_prefix', '/test', true);
  v_html := pgv.page('Brand', 'Title', '/test/', '[{"href":"/","label":"H"}]'::jsonb, '<p>Body</p>');
  RETURN NEXT ok(v_html NOT LIKE '%style=%', 'page has no inline style');
END;
$function$;
