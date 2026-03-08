CREATE OR REPLACE FUNCTION shop.pgv_order(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html  text;
  v_md    text;
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

  -- Items table (Markdown)
  v_html := v_html || '<h3>Items</h3>';
  v_md := E'| Product | Qty | Unit Price | Subtotal |\n| --- | --- | --- | --- |\n';
  FOR r IN
    SELECT p.name, oi.quantity, oi.unit_price, oi.subtotal
    FROM shop.order_items oi
    JOIN shop.products p ON p.id = oi.product_id
    WHERE oi.order_id = p_id ORDER BY oi.id
  LOOP
    v_md := v_md || format(E'| %s | %s | %s | %s |\n',
      shop.esc(r.name), r.quantity, shop.pgv_money(r.unit_price),
      shop.pgv_money(r.subtotal));
  END LOOP;
  v_html := v_html || '<figure><md>' || v_md || '</md></figure>';

  v_html := v_html || '<a href="/orders" role="button" class="outline">Back to orders</a>';
  v_html := v_html || '</main>';
  RETURN v_html;
END;
$function$;
