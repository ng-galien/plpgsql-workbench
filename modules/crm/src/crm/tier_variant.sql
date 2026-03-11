CREATE OR REPLACE FUNCTION crm.tier_variant(p_tier text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p_tier
    WHEN 'vip' THEN 'warning'
    WHEN 'premium' THEN 'primary'
    ELSE 'default'
  END;
$function$;
