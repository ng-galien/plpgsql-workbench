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
