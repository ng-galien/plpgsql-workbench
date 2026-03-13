CREATE OR REPLACE FUNCTION workbench.api_messages(p_module text DEFAULT NULL::text)
 RETURNS TABLE(id integer, from_module text, to_module text, msg_type text, subject text, body text, status text, resolution text, priority text, reply_to integer, payload jsonb, result jsonb, created_at timestamp with time zone, resolved_at timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT m.id, m.from_module, m.to_module, m.msg_type, m.subject, m.body,
         m.status, m.resolution, m.priority, m.reply_to,
         m.payload, m.result, m.created_at, m.resolved_at
    FROM workbench.agent_message m
   WHERE (p_module IS NULL OR m.from_module = p_module OR m.to_module = p_module)
   ORDER BY m.created_at DESC
   LIMIT 100;
$function$;
