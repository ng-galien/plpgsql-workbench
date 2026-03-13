CREATE OR REPLACE FUNCTION workbench.on_issue_report_insert()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_msg_id integer;
BEGIN
  INSERT INTO workbench.agent_message(from_module, to_module, msg_type, subject, body, priority, payload)
  VALUES (
    'shell',
    'lead',
    'issue_report',
    format('Issue #%s à traiter (%s)', NEW.id, NEW.issue_type),
    format('SELECT * FROM workbench.issue_report WHERE id = %s', NEW.id),
    CASE WHEN NEW.issue_type = 'bug' THEN 'high' ELSE 'normal' END,
    jsonb_build_object('issue_id', NEW.id)
  )
  RETURNING id INTO v_msg_id;

  -- Link issue to message and acknowledge
  NEW.message_id := v_msg_id;
  NEW.status := 'acknowledged';

  RETURN NEW;
END;
$function$;
