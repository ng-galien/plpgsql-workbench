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
CREATE OR REPLACE FUNCTION shop.apply_discount(p_code text, p_subtotal numeric, p_item_count integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_disc shop.discounts;
  v_amount numeric := 0;
  v_free_items integer;
BEGIN
  SELECT * INTO v_disc FROM shop.discounts WHERE code = p_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'discount code "%" not found', p_code;
  END IF;

  IF NOT v_disc.active THEN
    RAISE EXCEPTION 'discount code "%" is inactive', p_code;
  END IF;

  IF v_disc.expires_at IS NOT NULL AND v_disc.expires_at < now() THEN
    RAISE EXCEPTION 'discount code "%" has expired', p_code;
  END IF;

  IF p_subtotal < v_disc.min_order THEN
    RAISE EXCEPTION 'minimum order % required for discount "%"', v_disc.min_order, p_code;
  END IF;

  CASE v_disc.kind
    WHEN 'percentage' THEN
      v_amount := ROUND(p_subtotal * v_disc.value / 100, 2);
    WHEN 'fixed' THEN
      v_amount := LEAST(v_disc.value, p_subtotal);
    WHEN 'buy_x_get_y' THEN
      IF p_item_count >= v_disc.buy_x THEN
        v_free_items := (p_item_count / v_disc.buy_x) * v_disc.get_y_free;
        v_amount := ROUND(v_free_items * (p_subtotal / p_item_count), 2);
      END IF;
  END CASE;

  RETURN v_amount;
END;
$function$;
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
CREATE OR REPLACE FUNCTION shop.get_catalog(p_search text DEFAULT NULL::text, p_in_stock_only boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'products', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'name', p.name,
        'price', p.price,
        'stock', p.stock,
        'available', p.stock > 0
      ) ORDER BY p.name
    ), '[]'::jsonb),
    'total', count(*),
    'in_stock', count(*) FILTER (WHERE p.stock > 0)
  ) INTO v_result
  FROM shop.products p
  WHERE (p_search IS NULL OR p.name ILIKE '%' || p_search || '%')
    AND (NOT p_in_stock_only OR p.stock > 0);

  RETURN v_result;
END;
$function$;
CREATE OR REPLACE FUNCTION shop.get_order_details(p_order_id integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_order shop.orders;
  v_items jsonb;
  v_customer jsonb;
BEGIN
  SELECT * INTO v_order FROM shop.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', format('order %s not found', p_order_id));
  END IF;

  -- Customer info
  SELECT jsonb_build_object(
    'id', c.id, 'name', c.name, 'email', c.email,
    'tier', shop.customer_tier(c.id)
  ) INTO v_customer
  FROM shop.customers c WHERE c.id = v_order.customer_id;

  -- Line items with product names
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'product', p.name,
      'quantity', oi.quantity,
      'unit_price', oi.unit_price,
      'subtotal', oi.subtotal
    ) ORDER BY oi.id
  ), '[]'::jsonb) INTO v_items
  FROM shop.order_items oi
  JOIN shop.products p ON p.id = oi.product_id
  WHERE oi.order_id = p_order_id;

  RETURN jsonb_build_object(
    'order_id', v_order.id,
    'status', v_order.status,
    'customer', v_customer,
    'items', v_items,
    'subtotal', v_order.subtotal,
    'discount_code', v_order.discount_code,
    'discount_amount', v_order.discount_amount,
    'total', v_order.total,
    'created_at', v_order.created_at
  );
END;
$function$;
CREATE OR REPLACE FUNCTION shop.get_customer_dashboard(p_customer_id integer)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_customer shop.customers;
  v_tier text;
  v_stats jsonb;
  v_recent_orders jsonb;
BEGIN
  SELECT * INTO v_customer FROM shop.customers WHERE id = p_customer_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', format('customer %s not found', p_customer_id));
  END IF;

  v_tier := shop.customer_tier(p_customer_id);

  -- Aggregate stats
  SELECT jsonb_build_object(
    'total_orders', count(*),
    'total_spent', COALESCE(sum(total), 0),
    'avg_order', COALESCE(round(avg(total), 2), 0),
    'cancelled', count(*) FILTER (WHERE status = 'cancelled')
  ) INTO v_stats
  FROM shop.orders WHERE customer_id = p_customer_id;

  -- Last 5 orders
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'order_id', o.id,
      'status', o.status,
      'total', o.total,
      'items', (SELECT count(*) FROM shop.order_items WHERE order_id = o.id),
      'created_at', o.created_at
    ) ORDER BY o.created_at DESC
  ), '[]'::jsonb) INTO v_recent_orders
  FROM (
    SELECT * FROM shop.orders
    WHERE customer_id = p_customer_id
    ORDER BY created_at DESC LIMIT 5
  ) o;

  RETURN jsonb_build_object(
    'customer', jsonb_build_object(
      'id', v_customer.id,
      'name', v_customer.name,
      'email', v_customer.email,
      'member_since', v_customer.created_at
    ),
    'tier', v_tier,
    'tier_discount', CASE v_tier
      WHEN 'platinum' THEN 10
      WHEN 'gold' THEN 5
      WHEN 'silver' THEN 2
      ELSE 0
    END,
    'stats', v_stats,
    'recent_orders', v_recent_orders
  );
END;
$function$;
