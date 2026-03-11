CREATE OR REPLACE FUNCTION ops_ut.test_recent_events()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  -- The dashboard shows recent events from hook_log and agent_message
  -- We have hook events from this session already
  v_html := ops.get_index();
  RETURN NEXT ok(v_html LIKE '%Activite recente%', 'get_index shows recent events section');
  RETURN NEXT ok(v_html LIKE '%hook%' OR v_html LIKE '%message%', 'timeline contains event badges');
END;
$function$;
