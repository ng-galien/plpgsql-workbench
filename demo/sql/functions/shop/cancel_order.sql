CREATE OR REPLACE FUNCTION shop.cancel_order(p_order_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_order shop.orders;
  v_item record;
BEGIN
  SELECT * INTO v_order FROM shop.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'order % not found', p_order_id;
  END IF;

  IF v_order.status = 'cancelled' THEN
    RETURN false;  -- already cancelled, idempotent
  END IF;

  IF v_order.status = 'shipped' THEN
    RAISE EXCEPTION 'cannot cancel shipped order %', p_order_id;
  END IF;

  -- Restore stock for each item
  FOR v_item IN
    SELECT product_id, quantity FROM shop.order_items WHERE order_id = p_order_id
  LOOP
    UPDATE shop.products SET stock = stock + v_item.quantity WHERE id = v_item.product_id;
  END LOOP;

  UPDATE shop.orders SET status = 'cancelled' WHERE id = p_order_id;
  RETURN true;
END;
$function$;
