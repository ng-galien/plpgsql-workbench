CREATE OR REPLACE FUNCTION ops_ut.test_get_agents()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := ops.get_agents();
  RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 0, 'get_agents renders HTML');
  RETURN NEXT ok(v_html LIKE '%opsTmuxGrid%', 'get_agents contains Alpine grid component');
  RETURN NEXT ok(v_html LIKE '%ops-agent-card%', 'get_agents contains card structure');
  RETURN NEXT ok(v_html LIKE '%ops-agent-chevron%', 'get_agents contains chevron');
  RETURN NEXT ok(v_html LIKE '%ops-agent-status%', 'get_agents contains status span');
  RETURN NEXT ok(v_html LIKE '%expandAll()%', 'get_agents has expand all button');
  RETURN NEXT ok(v_html LIKE '%collapseAll()%', 'get_agents has collapse all button');
  RETURN NEXT ok(v_html LIKE '%pgv-empty%', 'get_agents has empty state fallback');
  -- No inline styles
  RETURN NEXT ok(v_html NOT LIKE '%style="%', 'get_agents has no inline styles');
END;
$function$;
