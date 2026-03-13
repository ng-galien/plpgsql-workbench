CREATE OR REPLACE FUNCTION workbench.ack_resolved(p_module text)
 RETURNS TABLE(id integer, to_module text, msg_type text, subject text, resolution text)
 LANGUAGE sql
AS $function$
  UPDATE workbench.agent_message
    SET acknowledged_at = resolved_at
    WHERE from_module = p_module
      AND status = 'resolved'
      AND (acknowledged_at IS NULL OR resolved_at > acknowledged_at)
    RETURNING agent_message.id, agent_message.to_module, agent_message.msg_type,
              agent_message.subject, agent_message.resolution;
$function$;
