CREATE OR REPLACE FUNCTION pgv_ut.test_href_with_prefix()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM set_config('pgv.route_prefix', '/myschema', true);
  RETURN NEXT is(pgv.href('/atoms'), '/myschema/atoms', 'href prefixes path with schema');
  RETURN NEXT is(pgv.href('/'), '/myschema/', 'href prefixes root');
  PERFORM set_config('pgv.route_prefix', '', true);
  RETURN NEXT is(pgv.href('/atoms'), '/atoms', 'href returns raw path without prefix');
END;
$function$;
