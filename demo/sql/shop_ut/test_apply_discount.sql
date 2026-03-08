CREATE OR REPLACE FUNCTION shop_ut.test_apply_discount()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_amount numeric;
BEGIN
  -- Percentage discount: WELCOME10 = 10%
  v_amount := shop.apply_discount('WELCOME10', 100.00, 1);
  RETURN NEXT is(v_amount, 10.00, 'WELCOME10 gives 10% off');

  -- Fixed discount: FLAT25 = $25 off
  v_amount := shop.apply_discount('FLAT25', 100.00, 1);
  RETURN NEXT is(v_amount, 25.00, 'FLAT25 gives $25 off');

  -- Fixed discount capped at subtotal
  v_amount := shop.apply_discount('FLAT25', 10.00, 1);
  RETURN NEXT is(v_amount, 10.00, 'FLAT25 capped at subtotal when subtotal < 25');

  -- Buy X Get Y: BUY2GET1 = buy 2 get 1 free
  v_amount := shop.apply_discount('BUY2GET1', 90.00, 3);
  RETURN NEXT ok(v_amount > 0, 'BUY2GET1 gives a discount for 3 items');

  -- Unknown code
  RETURN NEXT throws_ok(
    'SELECT shop.apply_discount(''NOPE'', 100.00, 1)',
    'discount code "NOPE" not found');

  -- Inactive code
  RETURN NEXT throws_ok(
    'SELECT shop.apply_discount(''EXPIRED50'', 100.00, 1)',
    'discount code "EXPIRED50" is inactive');
END;
$function$;
