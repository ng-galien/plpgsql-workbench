CREATE OR REPLACE FUNCTION ops_ut.test_pages_render()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(length(ops.get_index()) > 0, 'get_index renders HTML');
  RETURN NEXT ok(length(ops.get_modules()) > 0, 'get_modules renders HTML');
  RETURN NEXT ok(length(ops.get_tests()) > 0, 'get_tests renders HTML');
  RETURN NEXT ok(length(ops.get_hooks()) > 0, 'get_hooks renders HTML');
  RETURN NEXT ok(length(ops.get_agent('cad')) > 0, 'get_agent renders HTML');

  -- Navigation
  RETURN NEXT ok(ops.brand() = 'Ops', 'brand returns Ops');
  RETURN NEXT ok(
    (ops.nav_items())::text LIKE '%Agents%',
    'nav_items contains Agents'
  );
  RETURN NEXT ok(
    (ops.nav_items())::text LIKE '%Modules%',
    'nav_items contains Modules'
  );
  RETURN NEXT ok(
    (ops.nav_items())::text LIKE '%Tests%',
    'nav_items contains Tests'
  );
END;
$function$;
