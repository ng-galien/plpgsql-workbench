CREATE OR REPLACE FUNCTION expense.expense_report_update(p_row expense.expense_report)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_result expense.expense_report;
BEGIN
  UPDATE expense.expense_report SET
    author = COALESCE(p_row.author, author),
    start_date = COALESCE(p_row.start_date, start_date),
    end_date = COALESCE(p_row.end_date, end_date),
    comment = COALESCE(p_row.comment, comment),
    updated_at = now()
  WHERE id = p_row.id AND status = 'draft'
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
