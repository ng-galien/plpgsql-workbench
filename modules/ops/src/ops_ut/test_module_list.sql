CREATE OR REPLACE FUNCTION ops_ut.test_module_list()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := ops.get_index();
  RETURN NEXT ok(length(v_html) > 100, 'get_index returns substantial HTML (uses _module_list)');
  RETURN NEXT ok(v_html LIKE '%cad%', 'get_index contains cad module card');
  -- New global stats
  RETURN NEXT ok(v_html LIKE '%Fonctions%', 'get_index shows total functions');
  RETURN NEXT ok(v_html LIKE '%Tests%', 'get_index shows total tests');
  RETURN NEXT ok(v_html LIKE '%Taches resolues%', 'get_index shows resolved tasks');
END;
$function$;
