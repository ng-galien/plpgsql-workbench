CREATE OR REPLACE FUNCTION shop_ut.test_cancel_order()
 RETURNS SETOF text
 LANGUAGE plpgsql
 SET search_path TO 'shop_ut', 'shop', 'public'
AS $function$
DECLARE
  v_cust integer;
  v_prod integer;
  v_order_id integer;
BEGIN
  INSERT INTO shop.customers (name, email) VALUES ('Bob', 'bob@shop.test') RETURNING id INTO v_cust;
  INSERT INTO shop.products (name, price, stock) VALUES ('Thing', 50.00, 10) RETURNING id INTO v_prod;

  -- Place and cancel
  v_order_id := place_order(v_cust, jsonb_build_array(
    jsonb_build_object('product_id', v_prod, 'quantity', 3)
  ));
  RETURN NEXT is((SELECT stock FROM shop.products WHERE id = v_prod), 7, 'stock reserved');

  RETURN NEXT is(cancel_order(v_order_id), true, 'cancel returns true');
  RETURN NEXT is((SELECT status FROM shop.orders WHERE id = v_order_id), 'cancelled', 'status cancelled');
  RETURN NEXT is((SELECT stock FROM shop.products WHERE id = v_prod), 10, 'stock restored');

  -- Cancel again (idempotent)
  RETURN NEXT is(cancel_order(v_order_id), false, 'double cancel returns false');

  -- Cannot cancel shipped
  v_order_id := place_order(v_cust, jsonb_build_array(
    jsonb_build_object('product_id', v_prod, 'quantity', 1)
  ));
  UPDATE shop.orders SET status = 'shipped' WHERE id = v_order_id;
  RETURN NEXT throws_ok(
    format($$SELECT shop.cancel_order(%s)$$, v_order_id),
    'P0001', NULL, 'cannot cancel shipped'
  );

  -- Unknown order
  RETURN NEXT throws_ok(
    $$SELECT shop.cancel_order(-999)$$,
    'P0001', NULL, 'unknown order throws'
  );
END;
$function$;
