CREATE OR REPLACE FUNCTION workbench.agent_message_update(p_row workbench.agent_message)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_row jsonb;
BEGIN
  UPDATE workbench.agent_message SET
    status      = coalesce(p_row.status, status),
    resolution  = coalesce(p_row.resolution, resolution),
    result      = coalesce(p_row.result, result),
    resolved_at = CASE WHEN p_row.status = 'resolved' THEN now() ELSE resolved_at END,
    acknowledged_at = CASE WHEN p_row.status = 'acknowledged' AND acknowledged_at IS NULL THEN now() ELSE acknowledged_at END
  WHERE id = p_row.id
  RETURNING to_jsonb(agent_message.*) INTO v_row;

  RETURN v_row;
END;
$function$;
