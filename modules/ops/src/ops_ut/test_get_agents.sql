CREATE OR REPLACE FUNCTION ops_ut.test_get_agents()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := ops.get_agents();
  RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 0, 'get_agents renders HTML');
  RETURN NEXT ok(v_html LIKE '%opsTmuxGrid%', 'get_agents uses opsTmuxGrid component');
  RETURN NEXT ok(v_html LIKE '%<table%', 'get_agents has table');
  RETURN NEXT ok(v_html LIKE '%activateSession%', 'get_agents has activateSession click handler');
  RETURN NEXT ok(v_html LIKE '%data-terminal-for%', 'get_agents has terminal container');
  RETURN NEXT ok(v_html LIKE '%ops-agent-dot%', 'get_agents has connection status dot');
  RETURN NEXT ok(v_html LIKE '%pgv-badge%', 'get_agents has status badge');
  RETURN NEXT ok(v_html LIKE '%pgv-empty%', 'get_agents has empty state fallback');
  RETURN NEXT ok(v_html NOT LIKE '%style="%', 'get_agents has no inline styles');
END;
$function$;
