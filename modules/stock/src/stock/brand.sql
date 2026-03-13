CREATE OR REPLACE FUNCTION stock.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT pgv.t('stock.brand');
$function$;
