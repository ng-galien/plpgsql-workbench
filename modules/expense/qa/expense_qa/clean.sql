CREATE OR REPLACE FUNCTION expense_qa.clean()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM expense.ligne;
  DELETE FROM expense.note;
  RETURN 'expense data cleaned';
END;
$function$;
