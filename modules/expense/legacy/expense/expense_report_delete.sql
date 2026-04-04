CREATE OR REPLACE FUNCTION expense.expense_report_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_result expense.expense_report;
BEGIN
  DELETE FROM expense.expense_report WHERE (id = p_id::int OR reference = p_id) AND status = 'draft'
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
