CREATE OR REPLACE FUNCTION workbench.api_sessions()
 RETURNS TABLE(module text, status text, pid integer, started_at timestamp with time zone, ended_at timestamp with time zone, last_activity timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT s.module, s.status, s.pid, s.started_at, s.ended_at, s.last_activity
    FROM workbench.agent_session s
   ORDER BY s.started_at DESC
   LIMIT 50;
$function$;
