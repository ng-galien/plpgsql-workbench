CREATE OR REPLACE FUNCTION ops_ut.test_recent_events()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  v_html := ops.get_index();
  RETURN NEXT ok(v_html LIKE '%opsTmuxGrid%', 'get_index is the agents view');
  RETURN NEXT ok(v_html LIKE '%activateSession%', 'get_index has session activation');
END;
$function$;
