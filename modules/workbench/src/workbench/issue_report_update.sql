CREATE OR REPLACE FUNCTION workbench.issue_report_update(p_row workbench.issue_report)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row jsonb;
BEGIN
  UPDATE workbench.issue_report SET
    issue_type  = coalesce(p_row.issue_type, issue_type),
    module      = coalesce(p_row.module, module),
    description = coalesce(p_row.description, description),
    context     = coalesce(p_row.context, context),
    status      = coalesce(p_row.status, status),
    message_id  = coalesce(p_row.message_id, message_id)
  WHERE id = p_row.id
  RETURNING to_jsonb(issue_report.*) INTO v_row;

  RETURN v_row;
END;
$function$;
