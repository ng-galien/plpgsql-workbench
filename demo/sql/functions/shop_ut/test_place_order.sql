CREATE OR REPLACE FUNCTION shop_ut.test_place_order()
 RETURNS SETOF text
 LANGUAGE plpgsql
 SET search_path TO 'shop_ut', 'shop', 'public'
AS $function$
DECLARE
  v_cust integer;
  v_p1 integer;
  v_p2 integer;
  v_order_id integer;
  v_order shop.orders;
BEGIN
  -- Setup
  INSERT INTO shop.customers (name, email) VALUES ('Alice', 'alice@shop.test') RETURNING id INTO v_cust;
  INSERT INTO shop.products (name, price, stock) VALUES ('Widget', 25.00, 100) RETURNING id INTO v_p1;
  INSERT INTO shop.products (name, price, stock) VALUES ('Gadget', 75.00, 5) RETURNING id INTO v_p2;
  INSERT INTO shop.discounts (code, kind, value, min_order) VALUES ('SAVE10', 'percentage', 10, 50);

  -- Happy path: 2 widgets + 1 gadget = 125.00
  v_order_id := place_order(v_cust, jsonb_build_array(
    jsonb_build_object('product_id', v_p1, 'quantity', 2),
    jsonb_build_object('product_id', v_p2, 'quantity', 1)
  ));
  SELECT * INTO v_order FROM shop.orders WHERE id = v_order_id;
  RETURN NEXT is(v_order.subtotal, 125.00, 'subtotal correct');
  RETURN NEXT is(v_order.total, 125.00, 'total without discount');
  RETURN NEXT is(v_order.status, 'confirmed', 'status confirmed');

  -- Stock decreased
  RETURN NEXT is((SELECT stock FROM shop.products WHERE id = v_p1), 98, 'widget stock decreased');
  RETURN NEXT is((SELECT stock FROM shop.products WHERE id = v_p2), 4, 'gadget stock decreased');

  -- With discount code
  v_order_id := place_order(v_cust, jsonb_build_array(
    jsonb_build_object('product_id', v_p1, 'quantity', 4)
  ), 'SAVE10');
  SELECT * INTO v_order FROM shop.orders WHERE id = v_order_id;
  RETURN NEXT is(v_order.subtotal, 100.00, 'discounted subtotal');
  RETURN NEXT is(v_order.discount_amount, 10.00, '10% discount applied');
  RETURN NEXT is(v_order.total, 90.00, 'discounted total');

  -- Unknown customer
  RETURN NEXT throws_ok(
    format($$SELECT shop.place_order(%s, '[{"product_id":%s,"quantity":1}]'::jsonb)$$, -999, v_p1),
    'P0001', NULL, 'unknown customer throws'
  );

  -- Unknown product
  RETURN NEXT throws_ok(
    format($$SELECT shop.place_order(%s, '[{"product_id":-1,"quantity":1}]'::jsonb)$$, v_cust),
    'P0001', NULL, 'unknown product throws'
  );

  -- Insufficient stock
  RETURN NEXT throws_ok(
    format($$SELECT shop.place_order(%s, '[{"product_id":%s,"quantity":999}]'::jsonb)$$, v_cust, v_p2),
    'P0001', NULL, 'insufficient stock throws'
  );

  -- Empty items
  RETURN NEXT throws_ok(
    format($$SELECT shop.place_order(%s, '[]'::jsonb)$$, v_cust),
    'P0001', NULL, 'empty order throws'
  );
END;
$function$;
