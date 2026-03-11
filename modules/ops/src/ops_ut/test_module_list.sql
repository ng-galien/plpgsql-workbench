CREATE OR REPLACE FUNCTION ops_ut.test_module_list()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_count int;
BEGIN
  -- Test indirectly: get_index uses _module_list and renders cards
  -- If _module_list returns modules, get_index will contain agent cards
  SELECT length(ops.get_index()) INTO v_count;
  RETURN NEXT ok(v_count > 100, 'get_index returns substantial HTML (uses _module_list)');
  RETURN NEXT ok(
    ops.get_index() LIKE '%cad%',
    'get_index contains cad module card'
  );
END;
$function$;
