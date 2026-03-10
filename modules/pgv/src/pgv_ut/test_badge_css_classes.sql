CREATE OR REPLACE FUNCTION pgv_ut.test_badge_css_classes()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(
    pgv.badge('test') LIKE '%class="pgv-badge%',
    'badge(default) outputs class pgv-badge'
  );
  RETURN NEXT ok(
    pgv.badge('test') NOT LIKE '%style=%',
    'badge(default) has no inline style'
  );
  RETURN NEXT ok(
    pgv.badge('ok', 'success') LIKE '%pgv-badge-success%',
    'badge(success) outputs pgv-badge-success'
  );
  RETURN NEXT ok(
    pgv.badge('ko', 'danger') LIKE '%pgv-badge-danger%',
    'badge(danger) outputs pgv-badge-danger'
  );
  RETURN NEXT ok(
    pgv.badge('w', 'warning') LIKE '%pgv-badge-warning%',
    'badge(warning) outputs pgv-badge-warning'
  );
  RETURN NEXT ok(
    pgv.badge('i', 'info') LIKE '%pgv-badge-info%',
    'badge(info) outputs pgv-badge-info'
  );
  RETURN NEXT ok(
    pgv.badge('p', 'primary') LIKE '%pgv-badge-primary%',
    'badge(primary) outputs pgv-badge-primary'
  );
END;
$function$;
