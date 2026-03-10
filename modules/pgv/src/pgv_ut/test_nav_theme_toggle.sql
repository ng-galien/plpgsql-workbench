CREATE OR REPLACE FUNCTION pgv_ut.test_nav_theme_toggle()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v text;
BEGIN
  v := pgv.nav('B', '[{"href":"/","label":"H"}]'::jsonb, '/');
  RETURN NEXT ok(v LIKE '%data-toggle-theme%', 'nav has theme toggle');
  RETURN NEXT ok(v LIKE '%pgv-theme-toggle%', 'theme toggle has CSS class');
END;
$function$;
