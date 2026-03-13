CREATE OR REPLACE FUNCTION ops_ut.test_get_tools()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := ops.get_tools();

  RETURN NEXT ok(v_html IS NOT NULL, 'get_tools returns HTML');
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'has stat widgets');
  RETURN NEXT ok(v_html LIKE '%pg_query%', 'lists pg_query tool');
  RETURN NEXT ok(v_html LIKE '%pg_func_set%', 'lists pg_func_set tool');
  RETURN NEXT ok(v_html LIKE '%/ops/tool?p_name=%', 'has detail links');
  RETURN NEXT ok(v_html NOT LIKE '%style="%', 'no inline styles');
END;
$function$;
