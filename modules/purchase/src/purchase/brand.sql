CREATE OR REPLACE FUNCTION purchase.brand()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN pgv.t('purchase.brand');
END;
$function$;
