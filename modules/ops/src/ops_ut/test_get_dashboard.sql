CREATE OR REPLACE FUNCTION ops_ut.test_get_dashboard()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := ops.get_dashboard();
  RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 0, 'get_dashboard renders HTML');
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'get_dashboard contains stat widgets');
  RETURN NEXT ok(v_html LIKE '%Fonctions%', 'get_dashboard shows total functions');
  RETURN NEXT ok(v_html LIKE '%Tests%', 'get_dashboard shows total tests');
  RETURN NEXT ok(v_html LIKE '%cad%', 'get_dashboard lists cad module');
  -- No inline styles
  RETURN NEXT ok(v_html NOT LIKE '%style="%', 'get_dashboard has no inline styles');
END;
$function$;
