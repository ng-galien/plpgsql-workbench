CREATE OR REPLACE FUNCTION ops_ut.test_module_stats()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := ops.get_agent('cad');
  RETURN NEXT ok(v_html IS NOT NULL, 'get_agent(cad) returns HTML');
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'get_agent contains stat widgets');
  RETURN NEXT ok(v_html LIKE '%Fonctions%', 'get_agent shows function count');
END;
$function$;
