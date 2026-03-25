CREATE OR REPLACE FUNCTION expense_qa.clean()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM expense.line;
  DELETE FROM expense.expense_report;
  RETURN 'expense data cleaned';
END;
$function$;
