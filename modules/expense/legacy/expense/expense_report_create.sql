CREATE OR REPLACE FUNCTION expense.expense_report_create(p_row expense.expense_report)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_ref text;
  v_result expense.expense_report;
BEGIN
  v_ref := expense._next_reference();
  INSERT INTO expense.expense_report (reference, author, start_date, end_date, comment)
  VALUES (v_ref, p_row.author, p_row.start_date, p_row.end_date, p_row.comment)
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
