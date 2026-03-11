CREATE OR REPLACE FUNCTION ledger.brand()
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN 'Comptabilité';
END;
$function$;
