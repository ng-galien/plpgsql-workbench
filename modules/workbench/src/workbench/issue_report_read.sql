CREATE OR REPLACE FUNCTION workbench.issue_report_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_row jsonb;
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

  RETURN v_row;
END;
$function$;
