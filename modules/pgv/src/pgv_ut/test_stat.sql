CREATE OR REPLACE FUNCTION pgv_ut.test_stat()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := pgv.stat('Label', '42', 'detail');
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'stat has pgv-stat class');
  RETURN NEXT ok(v_html LIKE '%pgv-stat-value%', 'stat has pgv-stat-value class');
  RETURN NEXT ok(v_html NOT LIKE '%style=%', 'stat has no inline style');
END;
$function$;
