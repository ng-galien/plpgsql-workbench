CREATE OR REPLACE FUNCTION workbench.agent_message_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_row jsonb;
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

  RETURN v_row;
END;
$function$;
