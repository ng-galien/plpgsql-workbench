CREATE OR REPLACE FUNCTION quote.brand()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN 'Facturation';
END;
$function$;
