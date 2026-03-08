-- ============================================================
-- pgView: Server-Side Rendering in PL/pgSQL
-- The DB generates HTML. The browser is a dumb renderer.
-- ============================================================

-- Helper: extract URL segment  /customers/42 → segment(2) = '42'
CREATE FUNCTION shop.path_segment(p_path text, p_pos integer)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT (string_to_array(trim(LEADING '/' FROM p_path), '/'))[p_pos];
$$;

-- Helper: HTML-escape user data
CREATE FUNCTION shop.esc(p_text text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT replace(replace(replace(replace(
    COALESCE(p_text, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;');
$$;

-- Helper: format money
CREATE FUNCTION shop.pgv_money(p_amount numeric)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT '$' || to_char(COALESCE(p_amount, 0), 'FM999,999,990.00');
$$;

-- Helper: colored badge
CREATE FUNCTION shop.pgv_badge(p_text text, p_variant text DEFAULT 'default')
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT format(
    '<span style="display:inline-block;padding:2px 10px;border-radius:12px;font-size:0.85em;font-weight:500;%s">%s</span>',
    CASE p_variant
      WHEN 'success'  THEN 'background:#d4edda;color:#155724'
      WHEN 'danger'   THEN 'background:#f8d7da;color:#721c24'
      WHEN 'warning'  THEN 'background:#fff3cd;color:#856404'
      WHEN 'info'     THEN 'background:#cce5ff;color:#004085'
      WHEN 'platinum' THEN 'background:linear-gradient(135deg,#e5e4e2,#b8b8b8);color:#333'
      WHEN 'gold'     THEN 'background:linear-gradient(135deg,#ffd700,#daa520);color:#333'
      WHEN 'silver'   THEN 'background:linear-gradient(135deg,#c0c0c0,#a0a0a0);color:#333'
      WHEN 'bronze'   THEN 'background:linear-gradient(135deg,#cd7f32,#a0522d);color:#fff'
      ELSE                  'background:#e2e3e5;color:#383d41'
    END,
    p_text
  );
$$;

-- Helper: status → badge
CREATE FUNCTION shop.pgv_status(p_status text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT shop.pgv_badge(p_status,
    CASE p_status
      WHEN 'confirmed' THEN 'success'
      WHEN 'shipped'   THEN 'info'
      WHEN 'pending'   THEN 'warning'
      WHEN 'cancelled' THEN 'danger'
      ELSE 'default'
    END);
$$;

-- Helper: tier → badge
CREATE FUNCTION shop.pgv_tier(p_tier text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT shop.pgv_badge(p_tier, p_tier);
$$;

-- Navigation bar
CREATE FUNCTION shop.pgv_nav(p_path text)
RETURNS text LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  RETURN format(
    '<nav class="container-fluid" style="border-bottom:1px solid var(--pico-muted-border-color);margin-bottom:2rem">
      <ul><li><strong>pgView Shop</strong></li></ul>
      <ul>
        <li><a href="/" %s>Dashboard</a></li>
        <li><a href="/products" %s>Products</a></li>
        <li><a href="/customers" %s>Customers</a></li>
        <li><a href="/orders" %s>Orders</a></li>
      </ul>
    </nav>',
    CASE WHEN p_path = '/' THEN 'aria-current="page"' ELSE '' END,
    CASE WHEN p_path LIKE '/products%' THEN 'aria-current="page"' ELSE '' END,
    CASE WHEN p_path LIKE '/customers%' THEN 'aria-current="page"' ELSE '' END,
    CASE WHEN p_path LIKE '/orders%' THEN 'aria-current="page"' ELSE '' END
  );
END;
$$;

-- ============================================================
-- PAGE: Dashboard
-- ============================================================
CREATE FUNCTION shop.pgv_dashboard()
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_customers bigint;
  v_products  bigint;
  v_orders    bigint;
  v_revenue   numeric;
  v_html      text;
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
  v_html := v_html || '<figure><table><thead><tr>';
  v_html := v_html || '<th>#</th><th>Customer</th><th>Status</th><th>Total</th><th>Date</th>';
  v_html := v_html || '</tr></thead><tbody>';

  FOR r IN
    SELECT o.id, c.name AS customer, o.status, o.total,
           to_char(o.created_at, 'YYYY-MM-DD') AS dt
    FROM shop.orders o
    JOIN shop.customers c ON c.id = o.customer_id
    ORDER BY o.created_at DESC LIMIT 10
  LOOP
    v_html := v_html || format(
      '<tr onclick="go(''/orders/%s'')" style="cursor:pointer">
        <td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
      r.id, r.id, shop.esc(r.customer), shop.pgv_status(r.status),
      shop.pgv_money(r.total), r.dt);
  END LOOP;

  v_html := v_html || '</tbody></table></figure>';

  -- Quick stats
  v_html := v_html || '<div class="grid">';
  v_html := v_html || '<article><h4>Top Products</h4><table><tbody>';
  FOR r IN
    SELECT p.name, sum(oi.quantity) AS sold
    FROM shop.order_items oi
    JOIN shop.products p ON p.id = oi.product_id
    JOIN shop.orders o ON o.id = oi.order_id AND o.status != 'cancelled'
    GROUP BY p.name ORDER BY sold DESC LIMIT 5
  LOOP
    v_html := v_html || format('<tr><td>%s</td><td>%s sold</td></tr>',
      shop.esc(r.name), r.sold);
  END LOOP;
  v_html := v_html || '</tbody></table></article>';

  v_html := v_html || '<article><h4>Low Stock</h4><table><tbody>';
  FOR r IN
    SELECT name, stock FROM shop.products
    WHERE stock < 20 ORDER BY stock ASC LIMIT 5
  LOOP
    v_html := v_html || format('<tr><td>%s</td><td>%s</td></tr>',
      shop.esc(r.name),
      CASE WHEN r.stock = 0 THEN shop.pgv_badge('Out', 'danger')
           ELSE shop.pgv_badge(r.stock || ' left', 'warning') END);
  END LOOP;
  v_html := v_html || '</tbody></table></article></div>';

  v_html := v_html || '</main>';
  RETURN v_html;
END;
$$;

-- ============================================================
-- PAGE: Products list
-- ============================================================
CREATE FUNCTION shop.pgv_products()
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_html text;
  r record;
BEGIN
  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>Products</h2><p>Catalog</p></hgroup>';
  v_html := v_html || '<figure><table><thead><tr>';
  v_html := v_html || '<th>Name</th><th>Price</th><th>Stock</th>';
  v_html := v_html || '</tr></thead><tbody>';

  FOR r IN SELECT * FROM shop.products ORDER BY name
  LOOP
    v_html := v_html || format(
      '<tr onclick="go(''/products/%s'')" style="cursor:pointer">
        <td>%s</td><td>%s</td><td>%s</td></tr>',
      r.id, shop.esc(r.name), shop.pgv_money(r.price),
      CASE WHEN r.stock > 10 THEN shop.pgv_badge(r.stock || '', 'success')
           WHEN r.stock > 0  THEN shop.pgv_badge(r.stock || '', 'warning')
           ELSE shop.pgv_badge('Out of stock', 'danger') END);
  END LOOP;

  v_html := v_html || '</tbody></table></figure></main>';
  RETURN v_html;
END;
$$;

-- ============================================================
-- PAGE: Product detail
-- ============================================================
CREATE FUNCTION shop.pgv_product(p_id integer)
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_html text;
  r shop.products;
BEGIN
  SELECT * INTO r FROM shop.products WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN '<main class="container"><article><p>Product not found.</p><footer><a href="/products">Back</a></footer></article></main>';
  END IF;

  v_html := '<main class="container">';
  v_html := v_html || format('<hgroup><h2>%s</h2><p>Product #%s</p></hgroup>', shop.esc(r.name), r.id);
  v_html := v_html || '<article><dl>';
  v_html := v_html || format('<dt>Price</dt><dd><strong>%s</strong></dd>', shop.pgv_money(r.price));
  v_html := v_html || format('<dt>Stock</dt><dd>%s units</dd>', r.stock);
  v_html := v_html || format('<dt>Status</dt><dd>%s</dd>',
    CASE WHEN r.stock > 0 THEN shop.pgv_badge('In Stock', 'success')
         ELSE shop.pgv_badge('Out of Stock', 'danger') END);
  v_html := v_html || '</dl>';
  v_html := v_html || '<footer><a href="/products" role="button" class="outline">Back to catalog</a></footer>';
  v_html := v_html || '</article></main>';
  RETURN v_html;
END;
$$;

-- ============================================================
-- PAGE: Customers list
-- ============================================================
CREATE FUNCTION shop.pgv_customers()
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_html text;
  r record;
BEGIN
  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>Customers</h2><p>All registered customers</p></hgroup>';
  v_html := v_html || '<figure><table><thead><tr>';
  v_html := v_html || '<th>Name</th><th>Email</th><th>Tier</th><th>Since</th>';
  v_html := v_html || '</tr></thead><tbody>';

  FOR r IN
    SELECT c.*, shop.customer_tier(c.id) AS tier,
           to_char(c.created_at, 'YYYY-MM-DD') AS dt
    FROM shop.customers c ORDER BY c.name
  LOOP
    v_html := v_html || format(
      '<tr onclick="go(''/customers/%s'')" style="cursor:pointer">
        <td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
      r.id, shop.esc(r.name), shop.esc(r.email),
      shop.pgv_tier(r.tier), r.dt);
  END LOOP;

  v_html := v_html || '</tbody></table></figure></main>';
  RETURN v_html;
END;
$$;

-- ============================================================
-- PAGE: Customer detail
-- ============================================================
CREATE FUNCTION shop.pgv_customer(p_id integer)
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_html  text;
  v_cust  shop.customers;
  v_tier  text;
  v_count bigint;
  v_spent numeric;
  r       record;
BEGIN
  SELECT * INTO v_cust FROM shop.customers WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN '<main class="container"><article><p>Customer not found.</p><footer><a href="/customers">Back</a></footer></article></main>';
  END IF;

  v_tier := shop.customer_tier(p_id);
  SELECT count(*), COALESCE(sum(total), 0)
    INTO v_count, v_spent
    FROM shop.orders WHERE customer_id = p_id AND status != 'cancelled';

  v_html := '<main class="container">';
  v_html := v_html || format('<hgroup><h2>%s</h2><p>%s customer</p></hgroup>',
    shop.esc(v_cust.name), shop.pgv_tier(v_tier));

  -- Info + Stats side by side
  v_html := v_html || '<div class="grid"><article><dl>';
  v_html := v_html || format('<dt>Email</dt><dd>%s</dd>', shop.esc(v_cust.email));
  v_html := v_html || format('<dt>Member since</dt><dd>%s</dd>', to_char(v_cust.created_at, 'YYYY-MM-DD'));
  v_html := v_html || format('<dt>Tier discount</dt><dd>%s%%</dd>',
    CASE v_tier WHEN 'platinum' THEN 10 WHEN 'gold' THEN 5 WHEN 'silver' THEN 2 ELSE 0 END);
  v_html := v_html || '</dl></article>';

  v_html := v_html || '<article style="text-align:center"><dl>';
  v_html := v_html || format('<dt>Orders</dt><dd><strong>%s</strong></dd>', v_count);
  v_html := v_html || format('<dt>Total spent</dt><dd><strong>%s</strong></dd>', shop.pgv_money(v_spent));
  v_html := v_html || '</dl></article></div>';

  -- Orders
  v_html := v_html || '<h3>Orders</h3>';
  v_html := v_html || '<figure><table><thead><tr>';
  v_html := v_html || '<th>#</th><th>Status</th><th>Total</th><th>Date</th>';
  v_html := v_html || '</tr></thead><tbody>';

  FOR r IN
    SELECT o.id, o.status, o.total, to_char(o.created_at, 'YYYY-MM-DD') AS dt
    FROM shop.orders o WHERE o.customer_id = p_id ORDER BY o.created_at DESC
  LOOP
    v_html := v_html || format(
      '<tr onclick="go(''/orders/%s'')" style="cursor:pointer">
        <td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
      r.id, r.id, shop.pgv_status(r.status), shop.pgv_money(r.total), r.dt);
  END LOOP;

  v_html := v_html || '</tbody></table></figure>';
  v_html := v_html || '<a href="/customers" role="button" class="outline">Back to customers</a>';
  v_html := v_html || '</main>';
  RETURN v_html;
END;
$$;

-- ============================================================
-- PAGE: Orders list
-- ============================================================
CREATE FUNCTION shop.pgv_orders()
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_html text;
  r record;
BEGIN
  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>Orders</h2><p>All orders</p></hgroup>';
  v_html := v_html || '<p><a href="/orders/new" role="button">+ New Order</a></p>';
  v_html := v_html || '<figure><table><thead><tr>';
  v_html := v_html || '<th>#</th><th>Customer</th><th>Status</th><th>Items</th><th>Total</th><th>Date</th>';
  v_html := v_html || '</tr></thead><tbody>';

  FOR r IN
    SELECT o.id, c.name AS customer, o.status, o.total,
           to_char(o.created_at, 'YYYY-MM-DD') AS dt,
           (SELECT count(*) FROM shop.order_items WHERE order_id = o.id) AS items
    FROM shop.orders o
    JOIN shop.customers c ON c.id = o.customer_id
    ORDER BY o.created_at DESC
  LOOP
    v_html := v_html || format(
      '<tr onclick="go(''/orders/%s'')" style="cursor:pointer">
        <td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
      r.id, r.id, shop.esc(r.customer), shop.pgv_status(r.status),
      r.items, shop.pgv_money(r.total), r.dt);
  END LOOP;

  v_html := v_html || '</tbody></table></figure></main>';
  RETURN v_html;
END;
$$;

-- ============================================================
-- PAGE: Order detail
-- ============================================================
CREATE FUNCTION shop.pgv_order(p_id integer)
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_html  text;
  v_order shop.orders;
  v_cust  shop.customers;
  r       record;
BEGIN
  SELECT * INTO v_order FROM shop.orders WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN '<main class="container"><article><p>Order not found.</p><footer><a href="/orders">Back</a></footer></article></main>';
  END IF;

  SELECT * INTO v_cust FROM shop.customers WHERE id = v_order.customer_id;

  v_html := '<main class="container">';
  v_html := v_html || format('<hgroup><h2>Order #%s</h2><p>%s &mdash; %s</p></hgroup>',
    v_order.id, shop.pgv_status(v_order.status),
    to_char(v_order.created_at, 'YYYY-MM-DD HH24:MI'));

  -- Order info card
  v_html := v_html || '<article><dl>';
  v_html := v_html || format('<dt>Customer</dt><dd><a href="/customers/%s">%s</a></dd>',
    v_cust.id, shop.esc(v_cust.name));
  v_html := v_html || format('<dt>Subtotal</dt><dd>%s</dd>', shop.pgv_money(v_order.subtotal));

  IF v_order.discount_code IS NOT NULL THEN
    v_html := v_html || format('<dt>Discount</dt><dd><code>%s</code> &rarr; -%s</dd>',
      shop.esc(v_order.discount_code), shop.pgv_money(v_order.discount_amount));
  ELSIF v_order.discount_amount > 0 THEN
    v_html := v_html || format('<dt>Tier discount</dt><dd>-%s</dd>', shop.pgv_money(v_order.discount_amount));
  END IF;

  v_html := v_html || format('<dt>Total</dt><dd><strong style="font-size:1.2em">%s</strong></dd>',
    shop.pgv_money(v_order.total));
  v_html := v_html || '</dl>';

  -- Cancel button
  IF v_order.status IN ('pending', 'confirmed') THEN
    v_html := v_html || format(
      '<footer><button onclick="post(''/orders/%s/cancel'',{})" class="outline secondary">Cancel Order</button></footer>',
      v_order.id);
  END IF;
  v_html := v_html || '</article>';

  -- Items table
  v_html := v_html || '<h3>Items</h3>';
  v_html := v_html || '<figure><table><thead><tr>';
  v_html := v_html || '<th>Product</th><th>Qty</th><th>Unit Price</th><th>Subtotal</th>';
  v_html := v_html || '</tr></thead><tbody>';

  FOR r IN
    SELECT p.name, oi.quantity, oi.unit_price, oi.subtotal
    FROM shop.order_items oi
    JOIN shop.products p ON p.id = oi.product_id
    WHERE oi.order_id = p_id ORDER BY oi.id
  LOOP
    v_html := v_html || format(
      '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
      shop.esc(r.name), r.quantity, shop.pgv_money(r.unit_price),
      shop.pgv_money(r.subtotal));
  END LOOP;

  v_html := v_html || '</tbody></table></figure>';
  v_html := v_html || '<a href="/orders" role="button" class="outline">Back to orders</a>';
  v_html := v_html || '</main>';
  RETURN v_html;
END;
$$;

-- ============================================================
-- PAGE: New order form
-- ============================================================
CREATE FUNCTION shop.pgv_order_form()
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_html text;
  r record;
BEGIN
  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>New Order</h2><p>Place a new order</p></hgroup>';
  v_html := v_html || '<article><form id="order-form">';

  -- Customer select
  v_html := v_html || '<label>Customer';
  v_html := v_html || '<select name="customer_id" required>';
  v_html := v_html || '<option value="">Select a customer...</option>';
  FOR r IN SELECT id, name FROM shop.customers ORDER BY name
  LOOP
    v_html := v_html || format('<option value="%s">%s</option>', r.id, shop.esc(r.name));
  END LOOP;
  v_html := v_html || '</select></label>';

  -- Products table with quantity inputs
  v_html := v_html || '<fieldset><legend>Products</legend>';
  v_html := v_html || '<table><thead><tr><th>Product</th><th>Price</th><th>Stock</th><th>Qty</th></tr></thead><tbody>';

  FOR r IN SELECT * FROM shop.products WHERE stock > 0 ORDER BY name
  LOOP
    v_html := v_html || format(
      '<tr><td>%s</td><td>%s</td><td>%s</td><td><input type="number" data-pid="%s" value="0" min="0" max="%s" style="width:80px"></td></tr>',
      shop.esc(r.name), shop.pgv_money(r.price), r.stock, r.id, r.stock);
  END LOOP;

  v_html := v_html || '</tbody></table></fieldset>';

  -- Discount code
  v_html := v_html || '<label>Discount Code (optional)';
  v_html := v_html || '<input type="text" name="discount_code" placeholder="e.g. WELCOME10">';
  v_html := v_html || '</label>';

  v_html := v_html || '<div class="grid">';
  v_html := v_html || '<a href="/orders" role="button" class="outline secondary">Cancel</a>';
  v_html := v_html || '<button type="submit">Place Order</button>';
  v_html := v_html || '</div>';
  v_html := v_html || '</form></article>';

  -- Inline script for form handling
  v_html := v_html || '<script>
document.getElementById("order-form").addEventListener("submit", function(e) {
  e.preventDefault();
  var items = [];
  document.querySelectorAll("[data-pid]").forEach(function(input) {
    var qty = parseInt(input.value);
    if (qty > 0) items.push({ product_id: parseInt(input.dataset.pid), quantity: qty });
  });
  if (!items.length) { alert("Select at least one product"); return; }
  var cid = this.customer_id.value;
  if (!cid) { alert("Select a customer"); return; }
  var dc = this.discount_code.value || null;
  post("/orders/place", {
    customer_id: parseInt(cid),
    items: items,
    discount_code: dc
  });
});
</script>';

  v_html := v_html || '</main>';
  RETURN v_html;
END;
$$;

-- ============================================================
-- ACTIONS (POST — modify data, return redirect)
-- ============================================================

CREATE FUNCTION shop.pgv_place_order(p_body jsonb)
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_order_id integer;
BEGIN
  v_order_id := shop.place_order(
    (p_body->>'customer_id')::integer,
    p_body->'items',
    p_body->>'discount_code'
  );
  RETURN '<!-- redirect:/orders/' || v_order_id || ' -->';
EXCEPTION WHEN OTHERS THEN
  RETURN '<main class="container"><article>'
    || '<header>Error</header>'
    || '<p>' || shop.esc(SQLERRM) || '</p>'
    || '<footer><a href="/orders/new" role="button" class="outline">Try again</a></footer>'
    || '</article></main>';
END;
$$;

CREATE FUNCTION shop.pgv_cancel_order(p_id integer)
RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  PERFORM shop.cancel_order(p_id);
  RETURN '<!-- redirect:/orders/' || p_id || ' -->';
EXCEPTION WHEN OTHERS THEN
  RETURN '<main class="container"><article>'
    || '<header>Error</header>'
    || '<p>' || shop.esc(SQLERRM) || '</p>'
    || '<footer><a href="/orders/' || p_id || '" role="button" class="outline">Back</a></footer>'
    || '</article></main>';
END;
$$;

-- ============================================================
-- ROUTER: page(path, body) → HTML
-- ============================================================
CREATE FUNCTION shop.page(p_path text, p_body jsonb DEFAULT '{}')
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_content text;
BEGIN
  CASE
    -- Pages
    WHEN p_path = '/' THEN
      v_content := shop.pgv_dashboard();
    WHEN p_path = '/products' THEN
      v_content := shop.pgv_products();
    WHEN p_path ~ '^/products/(\d+)$' THEN
      v_content := shop.pgv_product(shop.path_segment(p_path, 2)::integer);
    WHEN p_path = '/customers' THEN
      v_content := shop.pgv_customers();
    WHEN p_path ~ '^/customers/(\d+)$' THEN
      v_content := shop.pgv_customer(shop.path_segment(p_path, 2)::integer);
    WHEN p_path = '/orders' THEN
      v_content := shop.pgv_orders();
    WHEN p_path = '/orders/new' THEN
      v_content := shop.pgv_order_form();
    WHEN p_path ~ '^/orders/(\d+)$' THEN
      v_content := shop.pgv_order(shop.path_segment(p_path, 2)::integer);

    -- Actions
    WHEN p_path = '/orders/place' THEN
      v_content := shop.pgv_place_order(p_body);
    WHEN p_path ~ '^/orders/(\d+)/cancel$' THEN
      v_content := shop.pgv_cancel_order(shop.path_segment(p_path, 2)::integer);

    -- 404
    ELSE
      v_content := '<main class="container"><article>'
        || '<header>Not Found</header>'
        || '<p>' || shop.esc(p_path) || '</p>'
        || '<footer><a href="/" role="button" class="outline">Go home</a></footer>'
        || '</article></main>';
  END CASE;

  -- Redirects pass through without nav
  IF v_content LIKE '<!-- redirect:%' THEN
    RETURN v_content;
  END IF;

  RETURN shop.pgv_nav(p_path) || v_content;
END;
$$;

-- Grant access to PostgREST
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA shop TO web_anon;
