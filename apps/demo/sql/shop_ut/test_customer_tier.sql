CREATE OR REPLACE FUNCTION shop_ut.test_customer_tier()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_tier text;
BEGIN
  -- Customer 1 has orders, should have a tier
  v_tier := shop.customer_tier(1);
  RETURN NEXT ok(v_tier IN ('bronze', 'silver', 'gold', 'platinum'),
    'customer_tier returns a valid tier: ' || v_tier);

  -- Non-existent customer → bronze (0 spent)
  v_tier := shop.customer_tier(99999);
  RETURN NEXT is(v_tier, 'bronze', 'non-existent customer gets bronze');
END;
$function$;
