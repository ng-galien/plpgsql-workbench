CREATE OR REPLACE FUNCTION workbench.session_create(p_module text, p_pid integer)
 RETURNS integer
 LANGUAGE sql
AS $function$
  INSERT INTO workbench.agent_session (module, status, pid, started_at)
    VALUES (p_module, 'running', p_pid, now())
    RETURNING id;
$function$;
