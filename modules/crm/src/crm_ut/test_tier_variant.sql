CREATE OR REPLACE FUNCTION crm_ut.test_tier_variant()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT is(crm.tier_variant('vip'), 'warning', 'vip -> warning');
  RETURN NEXT is(crm.tier_variant('premium'), 'primary', 'premium -> primary');
  RETURN NEXT is(crm.tier_variant('standard'), 'default', 'standard -> default');
END;
$function$;
