CREATE OR REPLACE FUNCTION expense.brand()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN pgv.t('expense.brand');
END;
$function$;
