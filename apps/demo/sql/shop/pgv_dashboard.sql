CREATE OR REPLACE FUNCTION shop.pgv_dashboard()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_customers bigint;
  v_products  bigint;
  v_orders    bigint;
  v_revenue   numeric;
  v_html      text;
  v_md        text;
  r           record;
BEGIN
  SELECT count(*) INTO v_customers FROM shop.customers;
  SELECT count(*) INTO v_products  FROM shop.products;
  SELECT count(*), COALESCE(sum(total), 0)
    INTO v_orders, v_revenue
    FROM shop.orders WHERE status != 'cancelled';

  v_html := '<main class="container"><h2>Dashboard</h2>';

  -- Stats grid
  v_html := v_html || '<div class="grid">';
  v_html := v_html || format('<article style="text-align:center"><h3 style="margin:0">%s</h3><small>Customers</small></article>', v_customers);
  v_html := v_html || format('<article style="text-align:center"><h3 style="margin:0">%s</h3><small>Products</small></article>', v_products);
  v_html := v_html || format('<article style="text-align:center"><h3 style="margin:0">%s</h3><small>Orders</small></article>', v_orders);
  v_html := v_html || format('<article style="text-align:center"><h3 style="margin:0">%s</h3><small>Revenue</small></article>', shop.pgv_money(v_revenue));
  v_html := v_html || '</div>';

  -- Recent orders
  v_html := v_html || '<h3>Recent Orders</h3>';
  v_md := E'| # | Customer | Status | Total | Date |\n| --- | --- | --- | --- | --- |\n';
  FOR r IN
    SELECT o.id, c.name AS customer, o.status, o.total,
           to_char(o.created_at, 'YYYY-MM-DD') AS dt
    FROM shop.orders o
    JOIN shop.customers c ON c.id = o.customer_id
    ORDER BY o.created_at DESC LIMIT 10
  LOOP
    v_md := v_md || format(E'| <a href="/orders/%s">%s</a> | %s | %s | %s | %s |\n',
      r.id, r.id, shop.esc(r.customer), shop.pgv_status(r.status),
      shop.pgv_money(r.total), r.dt);
  END LOOP;
  v_html := v_html || '<figure><md>' || v_md || '</md></figure>';

  -- Quick stats side by side
  v_html := v_html || '<div class="grid">';

  -- Top Products
  v_md := E'| Product | Sold |\n| --- | --- |\n';
  FOR r IN
    SELECT p.name, sum(oi.quantity) AS sold
    FROM shop.order_items oi
    JOIN shop.products p ON p.id = oi.product_id
    JOIN shop.orders o ON o.id = oi.order_id AND o.status != 'cancelled'
    GROUP BY p.name ORDER BY sold DESC LIMIT 5
  LOOP
    v_md := v_md || format(E'| %s | %s sold |\n', shop.esc(r.name), r.sold);
  END LOOP;
  v_html := v_html || '<article><h4>Top Products</h4><md>' || v_md || '</md></article>';

  -- Low Stock
  v_md := E'| Product | Stock |\n| --- | --- |\n';
  FOR r IN
    SELECT name, stock FROM shop.products
    WHERE stock < 20 ORDER BY stock ASC LIMIT 5
  LOOP
    v_md := v_md || format(E'| %s | %s |\n',
      shop.esc(r.name),
      CASE WHEN r.stock = 0 THEN shop.pgv_badge('Out', 'danger')
           ELSE shop.pgv_badge(r.stock || ' left', 'warning') END);
  END LOOP;
  v_html := v_html || '<article><h4>Low Stock</h4><md>' || v_md || '</md></article>';

  v_html := v_html || '</div></main>';
  RETURN v_html;
END;
$function$;
