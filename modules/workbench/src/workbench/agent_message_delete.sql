CREATE OR REPLACE FUNCTION workbench.agent_message_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row jsonb;
BEGIN
  DELETE FROM workbench.agent_message
  WHERE id = p_id::integer
  RETURNING to_jsonb(agent_message.*) INTO v_row;

  RETURN v_row;
END;
$function$;
