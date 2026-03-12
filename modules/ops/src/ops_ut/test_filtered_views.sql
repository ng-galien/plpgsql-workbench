CREATE OR REPLACE FUNCTION ops_ut.test_filtered_views()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  -- get_messages with filter
  v_html := ops.get_messages('cad');
  RETURN NEXT ok(v_html IS NOT NULL, 'get_messages(cad) returns HTML');

  -- get_messages with non-existent module -> empty state
  v_html := ops.get_messages('nonexistent_xyz');
  RETURN NEXT ok(v_html LIKE '%pgv-empty%', 'get_messages(nonexistent) shows empty state');

  -- get_hooks with filter
  v_html := ops.get_hooks('cad');
  RETURN NEXT ok(v_html IS NOT NULL, 'get_hooks(cad) returns HTML');

  -- get_hooks with non-existent module -> empty state
  v_html := ops.get_hooks('nonexistent_xyz');
  RETURN NEXT ok(v_html LIKE '%pgv-empty%', 'get_hooks(nonexistent) shows empty state');

  -- get_agent with non-existent module -> still renders (stats will be 0)
  v_html := ops.get_agent('nonexistent_xyz');
  RETURN NEXT ok(v_html IS NOT NULL, 'get_agent(nonexistent) renders without error');
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'get_agent(nonexistent) still shows stat widgets');
END;
$function$;
