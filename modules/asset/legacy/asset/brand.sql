CREATE OR REPLACE FUNCTION asset.brand()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN pgv.t('asset.brand');
END;
$function$;
