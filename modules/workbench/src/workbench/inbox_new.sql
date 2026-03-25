CREATE OR REPLACE FUNCTION workbench.inbox_new(p_module text)
 RETURNS TABLE(id integer, from_module text, msg_type text, subject text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
  SELECT m.id, m.from_module, m.msg_type, m.subject
    FROM workbench.agent_message m
   WHERE m.to_module = p_module
     AND m.status = 'new'
   ORDER BY m.created_at
   LIMIT 10;
$function$;
