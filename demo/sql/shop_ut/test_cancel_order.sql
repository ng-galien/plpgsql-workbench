CREATE OR REPLACE FUNCTION shop_ut.test_cancel_order()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_order_id integer;
  v_result boolean;
  v_stock_before integer;
  v_stock_after integer;
BEGIN
  -- Setup: place an order
  SELECT stock INTO v_stock_before FROM shop.products WHERE id = 1;
  v_order_id := shop.place_order(1, '[{"product_id":1,"quantity":1}]'::jsonb);

  -- Cancel it
  v_result := shop.cancel_order(v_order_id);
  RETURN NEXT ok(v_result, 'cancel_order returns true');

  RETURN NEXT is(
    (SELECT status FROM shop.orders WHERE id = v_order_id),
    'cancelled', 'order status is cancelled');

  -- Stock restored
  SELECT stock INTO v_stock_after FROM shop.products WHERE id = 1;
  RETURN NEXT is(v_stock_after, v_stock_before, 'stock restored after cancel');

  -- Idempotent: cancel again returns false
  v_result := shop.cancel_order(v_order_id);
  RETURN NEXT ok(NOT v_result, 'cancel_order is idempotent (returns false)');

  -- Non-existent order
  RETURN NEXT throws_ok(
    format('SELECT shop.cancel_order(%s)', 99999),
    'order 99999 not found');
END;
$function$;
