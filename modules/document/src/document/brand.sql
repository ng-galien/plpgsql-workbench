CREATE OR REPLACE FUNCTION document.brand()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN pgv.t('document.brand');
END;
$function$;
