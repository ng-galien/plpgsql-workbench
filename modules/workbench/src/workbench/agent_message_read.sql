CREATE OR REPLACE FUNCTION workbench.agent_message_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_row    jsonb;
  v_status text;
  v_actions jsonb := '[]'::jsonb;
  v_reply_count integer;
BEGIN
  SELECT to_jsonb(m) || jsonb_build_object(
    'issue_id', ir.id,
    'issue_type', ir.issue_type,
    'issue_status', ir.status
  )
  INTO v_row
  FROM workbench.agent_message m
  LEFT JOIN workbench.issue_report ir ON ir.message_id = m.id
  WHERE m.id = p_id::integer;

  IF v_row IS NULL THEN RETURN NULL; END IF;

  -- Stats
  SELECT count(*) INTO v_reply_count
  FROM workbench.agent_message
  WHERE reply_to = p_id::integer;

  v_row := v_row || jsonb_build_object('reply_count', v_reply_count);

  -- HATEOAS actions based on state
  v_status := v_row->>'status';
  CASE v_status
    WHEN 'new' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'acknowledge', 'uri', 'workbench://agent_message/' || p_id || '/acknowledge'),
        jsonb_build_object('method', 'resolve', 'uri', 'workbench://agent_message/' || p_id || '/resolve'),
        jsonb_build_object('method', 'delete', 'uri', 'workbench://agent_message/' || p_id || '/delete')
      );
    WHEN 'acknowledged' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'resolve', 'uri', 'workbench://agent_message/' || p_id || '/resolve'),
        jsonb_build_object('method', 'delete', 'uri', 'workbench://agent_message/' || p_id || '/delete')
      );
    WHEN 'resolved' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'delete', 'uri', 'workbench://agent_message/' || p_id || '/delete')
      );
    ELSE
      v_actions := '[]'::jsonb;
  END CASE;

  RETURN v_row || jsonb_build_object('actions', v_actions);
END;
$function$;
