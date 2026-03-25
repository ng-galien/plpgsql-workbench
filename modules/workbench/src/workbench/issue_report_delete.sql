CREATE OR REPLACE FUNCTION workbench.issue_report_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row jsonb;
BEGIN
  DELETE FROM workbench.issue_report
  WHERE id = p_id::integer
  RETURNING to_jsonb(issue_report.*) INTO v_row;

  RETURN v_row;
END;
$function$;
