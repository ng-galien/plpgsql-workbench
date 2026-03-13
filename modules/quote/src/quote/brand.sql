CREATE OR REPLACE FUNCTION quote.brand()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN pgv.t('quote.brand');
END;
$function$;
