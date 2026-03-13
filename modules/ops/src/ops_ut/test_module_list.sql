CREATE OR REPLACE FUNCTION ops_ut.test_module_list()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := ops.get_dashboard();
  RETURN NEXT ok(length(v_html) > 100, 'get_dashboard returns substantial HTML (uses _module_list)');
  RETURN NEXT ok(v_html LIKE '%cad%', 'get_dashboard contains cad module');
  RETURN NEXT ok(v_html LIKE '%Fonctions%', 'get_dashboard shows total functions');
  RETURN NEXT ok(v_html LIKE '%Tests%', 'get_dashboard shows total tests');
END;
$function$;
