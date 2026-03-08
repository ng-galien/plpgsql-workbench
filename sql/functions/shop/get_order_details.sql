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
