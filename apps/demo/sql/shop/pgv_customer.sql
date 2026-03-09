CREATE OR REPLACE FUNCTION shop.pgv_customer(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html  text;
  v_md    text;
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

  -- Orders (Markdown)
  v_html := v_html || '<h3>Orders</h3>';
  v_md := E'| # | Status | Total | Date |\n| --- | --- | --- | --- |\n';
  FOR r IN
    SELECT o.id, o.status, o.total, to_char(o.created_at, 'YYYY-MM-DD') AS dt
    FROM shop.orders o WHERE o.customer_id = p_id ORDER BY o.created_at DESC
  LOOP
    v_md := v_md || format(E'| <a href="/orders/%s">%s</a> | %s | %s | %s |\n',
      r.id, r.id, shop.pgv_status(r.status), shop.pgv_money(r.total), r.dt);
  END LOOP;
  v_html := v_html || '<figure><md>' || v_md || '</md></figure>';

  v_html := v_html || '<a href="/customers" role="button" class="outline">Back to customers</a>';
  v_html := v_html || '</main>';
  RETURN v_html;
END;
$function$;
