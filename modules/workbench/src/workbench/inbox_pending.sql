CREATE OR REPLACE FUNCTION workbench.inbox_pending(p_module text)
 RETURNS TABLE(id integer, from_module text, msg_type text, subject text, priority text)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT m.id, m.from_module, m.msg_type, m.subject, m.priority
    FROM workbench.agent_message m
   WHERE m.to_module = p_module
     AND m.status IN ('new', 'acknowledged')
   ORDER BY
     CASE WHEN m.priority = 'high' THEN 0 ELSE 1 END,
     m.created_at DESC
   LIMIT 10;
$function$;
