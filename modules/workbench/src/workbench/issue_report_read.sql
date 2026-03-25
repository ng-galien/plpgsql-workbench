CREATE OR REPLACE FUNCTION workbench.issue_report_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_row    jsonb;
  v_status text;
  v_actions jsonb := '[]'::jsonb;
  v_related_count integer;
BEGIN
  SELECT to_jsonb(i) || jsonb_build_object(
    'message_subject', m.subject,
    'message_from', m.from_module,
    'message_status', m.status
  )
  INTO v_row
  FROM workbench.issue_report i
  LEFT JOIN workbench.agent_message m ON m.id = i.message_id
  WHERE i.id = p_id::integer;

  IF v_row IS NULL THEN RETURN NULL; END IF;

  -- Stats
  SELECT count(*) INTO v_related_count
  FROM workbench.agent_message
  WHERE (payload->>'issue_id')::integer = p_id::integer;

  v_row := v_row || jsonb_build_object('related_message_count', v_related_count);

  -- HATEOAS actions based on state
  v_status := v_row->>'status';
  CASE v_status
    WHEN 'open' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'acknowledge', 'uri', 'workbench://issue_report/' || p_id || '/acknowledge'),
        jsonb_build_object('method', 'close', 'uri', 'workbench://issue_report/' || p_id || '/close'),
        jsonb_build_object('method', 'delete', 'uri', 'workbench://issue_report/' || p_id || '/delete')
      );
    WHEN 'acknowledged' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'resolve', 'uri', 'workbench://issue_report/' || p_id || '/resolve'),
        jsonb_build_object('method', 'close', 'uri', 'workbench://issue_report/' || p_id || '/close'),
        jsonb_build_object('method', 'delete', 'uri', 'workbench://issue_report/' || p_id || '/delete')
      );
    WHEN 'resolved' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'close', 'uri', 'workbench://issue_report/' || p_id || '/close'),
        jsonb_build_object('method', 'reopen', 'uri', 'workbench://issue_report/' || p_id || '/reopen'),
        jsonb_build_object('method', 'delete', 'uri', 'workbench://issue_report/' || p_id || '/delete')
      );
    WHEN 'closed' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'reopen', 'uri', 'workbench://issue_report/' || p_id || '/reopen'),
        jsonb_build_object('method', 'delete', 'uri', 'workbench://issue_report/' || p_id || '/delete')
      );
    ELSE
      v_actions := '[]'::jsonb;
  END CASE;

  RETURN v_row || jsonb_build_object('actions', v_actions);
END;
$function$;
