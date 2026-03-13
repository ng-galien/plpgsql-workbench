CREATE OR REPLACE FUNCTION ops_ut.test_get_tool()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := ops.get_tool('pg_query');

  RETURN NEXT ok(v_html IS NOT NULL, 'get_tool returns HTML');
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'has stat widgets');
  RETURN NEXT ok(v_html LIKE '%plpgsql%', 'shows pack name');
  RETURN NEXT ok(v_html LIKE '%/ops/tools%', 'breadcrumb links to tools list');
  RETURN NEXT ok(v_html NOT LIKE '%style="%', 'no inline styles');

  -- Unknown tool
  v_html := ops.get_tool('nonexistent_tool');
  RETURN NEXT ok(v_html LIKE '%introuvable%', 'unknown tool shows empty state');
END;
$function$;
