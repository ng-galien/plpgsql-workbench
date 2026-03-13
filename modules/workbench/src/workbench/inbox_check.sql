CREATE OR REPLACE FUNCTION workbench.inbox_check(p_module text)
 RETURNS TABLE(id integer, from_module text, msg_type text, subject text, body text, payload jsonb, reply_to integer, priority text)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT m.id, m.from_module, m.msg_type, m.subject,
         m.body, m.payload, m.reply_to, m.priority
    FROM workbench.agent_message m
   WHERE m.to_module = p_module
     AND m.status = 'new'
     AND m.priority = 'high'
   ORDER BY m.created_at DESC
   LIMIT 1;
$function$;
