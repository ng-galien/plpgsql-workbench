CREATE OR REPLACE FUNCTION shop.pgv_orders()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_md text;
  r record;
BEGIN
  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>Orders</h2><p>All orders</p></hgroup>';
  v_html := v_html || '<p><a href="/orders/new" role="button">+ New Order</a></p>';

  v_md := E'| # | Customer | Status | Items | Total | Date |\n| --- | --- | --- | --- | --- | --- |\n';
  FOR r IN
    SELECT o.id, c.name AS customer, o.status, o.total,
           to_char(o.created_at, 'YYYY-MM-DD') AS dt,
           (SELECT count(*) FROM shop.order_items WHERE order_id = o.id) AS items
    FROM shop.orders o
    JOIN shop.customers c ON c.id = o.customer_id
    ORDER BY o.created_at DESC
  LOOP
    v_md := v_md || format(E'| <a href="/orders/%s">%s</a> | %s | %s | %s | %s | %s |\n',
      r.id, r.id, shop.esc(r.customer), shop.pgv_status(r.status),
      r.items, shop.pgv_money(r.total), r.dt);
  END LOOP;

  v_html := v_html || '<figure><md>' || v_md || '</md></figure></main>';
  RETURN v_html;
END;
$function$;
