CREATE OR REPLACE FUNCTION stock.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT 'Stock';
$function$;
