CREATE OR REPLACE FUNCTION shop.place_order(p_customer_id integer, p_items jsonb, p_discount_code text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_order_id integer;
  v_item jsonb;
  v_product shop.products;
  v_qty integer;
  v_subtotal numeric := 0;
  v_item_count integer := 0;
  v_discount numeric := 0;
  v_tier_pct numeric;
BEGIN
  -- Validate customer
  PERFORM 1 FROM shop.customers WHERE id = p_customer_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'customer % not found', p_customer_id;
  END IF;

  -- Create order
  INSERT INTO shop.orders (customer_id) VALUES (p_customer_id) RETURNING id INTO v_order_id;

  -- Process items
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    SELECT * INTO v_product
    FROM shop.products
    WHERE id = (v_item->>'product_id')::integer
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'product % not found', v_item->>'product_id';
    END IF;

    v_qty := (v_item->>'quantity')::integer;

    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'quantity must be positive for product %', v_product.name;
    END IF;

    IF v_product.stock < v_qty THEN
      RAISE EXCEPTION 'insufficient stock for "%": have %, need %',
        v_product.name, v_product.stock, v_qty;
    END IF;

    -- Reserve stock
    UPDATE shop.products SET stock = stock - v_qty WHERE id = v_product.id;

    -- Add line item
    INSERT INTO shop.order_items (order_id, product_id, quantity, unit_price, subtotal)
    VALUES (v_order_id, v_product.id, v_qty, v_product.price, v_product.price * v_qty);

    v_subtotal := v_subtotal + (v_product.price * v_qty);
    v_item_count := v_item_count + v_qty;
  END LOOP;

  IF v_item_count = 0 THEN
    RAISE EXCEPTION 'order must contain at least one item';
  END IF;

  -- Apply discount code
  IF p_discount_code IS NOT NULL THEN
    v_discount := shop.apply_discount(p_discount_code, v_subtotal, v_item_count);
  END IF;

  -- Apply tier discount (stacks with code discount)
  v_tier_pct := CASE shop.customer_tier(p_customer_id)
    WHEN 'platinum' THEN 10
    WHEN 'gold' THEN 5
    WHEN 'silver' THEN 2
    ELSE 0
  END;

  IF v_tier_pct > 0 THEN
    v_discount := v_discount + ROUND((v_subtotal - v_discount) * v_tier_pct / 100, 2);
  END IF;

  -- Finalize
  UPDATE shop.orders
  SET subtotal = v_subtotal,
      discount_amount = v_discount,
      total = v_subtotal - v_discount,
      discount_code = p_discount_code,
      status = 'confirmed'
  WHERE id = v_order_id;

  RETURN v_order_id;
END;
$function$;
