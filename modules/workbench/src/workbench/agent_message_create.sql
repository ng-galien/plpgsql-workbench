CREATE OR REPLACE FUNCTION workbench.agent_message_create(p_row workbench.agent_message)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row jsonb;
BEGIN
  INSERT INTO workbench.agent_message (from_module, to_module, msg_type, subject, body, priority, reply_to, payload)
  VALUES (p_row.from_module, p_row.to_module, p_row.msg_type, p_row.subject, p_row.body,
          coalesce(p_row.priority, 'normal'), p_row.reply_to, p_row.payload)
  RETURNING to_jsonb(agent_message.*) INTO v_row;

  RETURN v_row;
END;
$function$;
