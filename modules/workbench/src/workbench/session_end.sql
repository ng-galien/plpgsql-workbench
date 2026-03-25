CREATE OR REPLACE FUNCTION workbench.session_end(p_id integer, p_status text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  UPDATE workbench.agent_session
    SET status = p_status, ended_at = now()
    WHERE id = p_id;
$function$;
