CREATE OR REPLACE FUNCTION ops_ut.test_get_modules()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := ops.get_modules();
  RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 0, 'get_modules renders HTML');
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'get_modules contains stat widgets');
  RETURN NEXT ok(v_html LIKE '%Modules%', 'get_modules shows module count');
  RETURN NEXT ok(v_html LIKE '%Fonctions%', 'get_modules shows function count');
  RETURN NEXT ok(v_html LIKE '%Tests%', 'get_modules shows test count');
  RETURN NEXT ok(v_html LIKE '%cad%', 'get_modules lists cad module');
  RETURN NEXT ok(v_html LIKE '%crm%', 'get_modules lists crm module');
  -- No inline styles
  RETURN NEXT ok(v_html NOT LIKE '%style="%', 'get_modules has no inline styles');
END;
$function$;
