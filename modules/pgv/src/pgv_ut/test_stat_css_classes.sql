CREATE OR REPLACE FUNCTION pgv_ut.test_stat_css_classes()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(
    pgv.stat('L', '42') LIKE '%class="pgv-stat"%',
    'stat outputs class pgv-stat'
  );
  RETURN NEXT ok(
    pgv.stat('L', '42') LIKE '%class="pgv-stat-value"%',
    'stat outputs class pgv-stat-value'
  );
  RETURN NEXT ok(
    pgv.stat('L', '42') NOT LIKE '%style=%',
    'stat has no inline style'
  );
END;
$function$;
