CREATE OR REPLACE FUNCTION shop_ut.test_customer_tier()
 RETURNS SETOF text
 LANGUAGE plpgsql
 SET search_path TO 'shop_ut', 'shop', 'public'
AS $function$
DECLARE
  v_cust integer;
BEGIN
  INSERT INTO shop.customers (name, email) VALUES ('Tester', 'tier@test.com') RETURNING id INTO v_cust;

  -- No orders -> bronze
  RETURN NEXT is(customer_tier(v_cust), 'bronze', 'no orders = bronze');

  -- 600 total -> silver
  INSERT INTO shop.orders (customer_id, status, total) VALUES (v_cust, 'confirmed', 600);
  RETURN NEXT is(customer_tier(v_cust), 'silver', '600 = silver');

  -- 2000 more -> gold
  INSERT INTO shop.orders (customer_id, status, total) VALUES (v_cust, 'confirmed', 2000);
  RETURN NEXT is(customer_tier(v_cust), 'gold', '2600 = gold');

  -- 3000 more -> platinum
  INSERT INTO shop.orders (customer_id, status, total) VALUES (v_cust, 'confirmed', 3000);
  RETURN NEXT is(customer_tier(v_cust), 'platinum', '5600 = platinum');

  -- Cancelled orders don't count
  INSERT INTO shop.orders (customer_id, status, total) VALUES (v_cust, 'cancelled', 99999);
  RETURN NEXT is(customer_tier(v_cust), 'platinum', 'cancelled orders excluded');
END;
$function$;
