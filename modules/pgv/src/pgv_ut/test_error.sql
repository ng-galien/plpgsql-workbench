CREATE OR REPLACE FUNCTION pgv_ut.test_error()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := pgv.error('404', 'Not found', 'Details');
  RETURN NEXT ok(v_html LIKE '%pgv-error%', 'error has pgv-error class');
  RETURN NEXT ok(v_html NOT LIKE '%style=%', 'error has no inline style');
END;
$function$;
