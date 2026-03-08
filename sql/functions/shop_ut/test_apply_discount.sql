CREATE OR REPLACE FUNCTION shop_ut.test_apply_discount()
 RETURNS SETOF text
 LANGUAGE plpgsql
 SET search_path TO 'shop_ut', 'shop', 'public'
AS $function$
BEGIN
  -- Setup discounts
  INSERT INTO shop.discounts (code, kind, value, min_order) VALUES ('SAVE10', 'percentage', 10, 50);
  INSERT INTO shop.discounts (code, kind, value, min_order) VALUES ('FLAT20', 'fixed', 20, 0);
  INSERT INTO shop.discounts (code, kind, value, buy_x, get_y_free) VALUES ('B2G1', 'buy_x_get_y', 0, 2, 1);
  INSERT INTO shop.discounts (code, kind, value, active) VALUES ('DEAD', 'percentage', 50, false);
  INSERT INTO shop.discounts (code, kind, value, expires_at) VALUES ('OLD', 'percentage', 50, '2020-01-01');
  INSERT INTO shop.discounts (code, kind, value, min_order) VALUES ('BIG', 'percentage', 5, 1000);

  -- Percentage discount
  RETURN NEXT is(apply_discount('SAVE10', 200.00, 3), 20.00, '10% of 200');

  -- Fixed discount
  RETURN NEXT is(apply_discount('FLAT20', 200.00, 3), 20.00, 'flat 20 off 200');
  -- Fixed capped at subtotal
  RETURN NEXT is(apply_discount('FLAT20', 10.00, 1), 10.00, 'fixed capped at subtotal');

  -- Buy 2 get 1 free (3 items at avg 33.33 each -> 1 free = 33.33)
  RETURN NEXT is(apply_discount('B2G1', 100.00, 3), 33.33, 'buy 2 get 1 free');
  -- Not enough items for B2G1
  RETURN NEXT is(apply_discount('B2G1', 50.00, 1), 0.00, 'b2g1 not enough items');

  -- Unknown code
  RETURN NEXT throws_ok(
    $$SELECT shop.apply_discount('NOPE', 100, 1)$$,
    'P0001', NULL, 'unknown code throws'
  );

  -- Inactive code
  RETURN NEXT throws_ok(
    $$SELECT shop.apply_discount('DEAD', 100, 1)$$,
    'P0001', NULL, 'inactive code throws'
  );

  -- Expired code
  RETURN NEXT throws_ok(
    $$SELECT shop.apply_discount('OLD', 100, 1)$$,
    'P0001', NULL, 'expired code throws'
  );

  -- Min order not met
  RETURN NEXT throws_ok(
    $$SELECT shop.apply_discount('BIG', 100, 1)$$,
    'P0001', NULL, 'min order throws'
  );
END;
$function$;
