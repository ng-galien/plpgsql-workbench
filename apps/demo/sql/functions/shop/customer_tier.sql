CREATE OR REPLACE FUNCTION shop.customer_tier(p_customer_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_total numeric;
BEGIN
  SELECT COALESCE(SUM(total), 0) INTO v_total
  FROM shop.orders
  WHERE customer_id = p_customer_id AND status != 'cancelled';

  RETURN CASE
    WHEN v_total >= 5000 THEN 'platinum'
    WHEN v_total >= 2000 THEN 'gold'
    WHEN v_total >= 500  THEN 'silver'
    ELSE 'bronze'
  END;
END;
$function$;
