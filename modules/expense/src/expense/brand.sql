CREATE OR REPLACE FUNCTION expense.brand()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN 'Notes de frais';
END;
$function$;
