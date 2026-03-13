CREATE OR REPLACE FUNCTION ledger.brand()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN pgv.t('ledger.brand');
END;
$function$;
