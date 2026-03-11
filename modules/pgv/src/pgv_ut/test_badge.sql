CREATE OR REPLACE FUNCTION pgv_ut.test_badge()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(pgv.badge('x') LIKE '%pgv-badge%', 'badge(default) has pgv-badge class');
  RETURN NEXT ok(pgv.badge('x') NOT LIKE '%style=%', 'badge(default) has no inline style');
  RETURN NEXT ok(pgv.badge('x', 'success') LIKE '%pgv-badge-success%', 'badge(success) has class');
  RETURN NEXT ok(pgv.badge('x', 'danger') LIKE '%pgv-badge-danger%', 'badge(danger) has class');
  RETURN NEXT ok(pgv.badge('x', 'warning') LIKE '%pgv-badge-warning%', 'badge(warning) has class');
  RETURN NEXT ok(pgv.badge('x', 'info') LIKE '%pgv-badge-info%', 'badge(info) has class');
  RETURN NEXT ok(pgv.badge('x', 'primary') LIKE '%pgv-badge-primary%', 'badge(primary) has class');
END;
$function$;
