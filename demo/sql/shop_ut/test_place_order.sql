CREATE OR REPLACE FUNCTION shop_ut.test_place_order()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_order_id integer;
  v_order shop.orders;
  v_stock_before integer;
  v_stock_after integer;
BEGIN
  -- Get initial stock
  SELECT stock INTO v_stock_before FROM shop.products WHERE id = 1;

  -- Place a simple order
  v_order_id := shop.place_order(
    1,
    '[{"product_id":1,"quantity":2}]'::jsonb
  );
  RETURN NEXT ok(v_order_id IS NOT NULL, 'place_order returns an order id');

  SELECT * INTO v_order FROM shop.orders WHERE id = v_order_id;
  RETURN NEXT is(v_order.status, 'confirmed', 'order status is confirmed');
  RETURN NEXT ok(v_order.total > 0, 'order total is positive');
  RETURN NEXT ok(v_order.subtotal >= v_order.total, 'total <= subtotal (tier discount may apply)');

  -- Stock decreased
  SELECT stock INTO v_stock_after FROM shop.products WHERE id = 1;
  RETURN NEXT is(v_stock_after, v_stock_before - 2, 'stock decreased by quantity');

  -- Items created
  RETURN NEXT is(
    (SELECT count(*)::integer FROM shop.order_items WHERE order_id = v_order_id),
    1, 'one line item created');

  -- Invalid customer
  RETURN NEXT throws_ok(
    'SELECT shop.place_order(9999, ''[{"product_id":1,"quantity":1}]''::jsonb)',
    'customer 9999 not found');

  -- Empty items
  RETURN NEXT throws_ok(
    'SELECT shop.place_order(1, ''[]''::jsonb)',
    'order must contain at least one item');
END;
$function$;
