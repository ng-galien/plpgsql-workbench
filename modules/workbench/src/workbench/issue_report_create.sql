CREATE OR REPLACE FUNCTION workbench.issue_report_create(p_row workbench.issue_report)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row jsonb;
BEGIN
  INSERT INTO workbench.issue_report (issue_type, module, description, context, status, message_id)
  VALUES (p_row.issue_type, p_row.module, p_row.description, p_row.context, coalesce(p_row.status, 'open'), p_row.message_id)
  RETURNING to_jsonb(issue_report.*) INTO v_row;

  RETURN v_row;
END;
$function$;
