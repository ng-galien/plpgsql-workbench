CREATE OR REPLACE FUNCTION ops_ut.test_get_tests()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  -- Full page (all schemas)
  v_html := ops.get_tests();
  RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 0, 'get_tests renders HTML');
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'get_tests contains stat widgets');
  RETURN NEXT ok(v_html LIKE '%Schemas%', 'get_tests shows schema count');
  RETURN NEXT ok(v_html LIKE '%cad_ut%', 'get_tests lists cad_ut');
  RETURN NEXT ok(v_html LIKE '%ops_ut%', 'get_tests lists ops_ut');
  RETURN NEXT ok(v_html LIKE '%Lancer%', 'get_tests has run buttons');
  RETURN NEXT ok(v_html NOT LIKE '%style="%', 'get_tests has no inline styles');

  -- Filtered by schema
  v_html := ops.get_tests('ops');
  RETURN NEXT ok(v_html LIKE '%ops_ut%', 'get_tests(ops) lists ops_ut');
  RETURN NEXT ok(v_html NOT LIKE '%cad_ut%', 'get_tests(ops) does not list cad_ut');
END;
$function$;
