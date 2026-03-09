CREATE OR REPLACE FUNCTION shop.pgv_tier(p_tier text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT shop.pgv_badge(p_tier, p_tier);
$function$;
