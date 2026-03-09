CREATE OR REPLACE FUNCTION shop.pgv_discounts()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  r shop.discounts;
BEGIN
  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>Discounts</h2><p>Available discount codes</p></hgroup>';
  v_html := v_html || '<figure><table><thead><tr>';
  v_html := v_html || '<th>Code</th><th>Type</th><th>Value</th><th>Min Order</th><th>Status</th>';
  v_html := v_html || '</tr></thead><tbody>';

  FOR r IN SELECT * FROM shop.discounts ORDER BY active DESC, code
  LOOP
    v_html := v_html || format(
      '<tr><td><code>%s</code></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
      shop.esc(r.code),
      CASE r.kind
        WHEN 'percentage' THEN shop.pgv_badge('%% off', 'info')
        WHEN 'fixed' THEN shop.pgv_badge('fixed', 'warning')
        WHEN 'buy_x_get_y' THEN shop.pgv_badge('buy X get Y', 'success')
      END,
      CASE r.kind
        WHEN 'percentage' THEN r.value || '%%'
        WHEN 'fixed' THEN shop.pgv_money(r.value)
        WHEN 'buy_x_get_y' THEN format('Buy %s get %s free', r.buy_x, r.get_y_free)
      END,
      CASE WHEN r.min_order > 0 THEN shop.pgv_money(r.min_order) ELSE '-' END,
      CASE WHEN r.active THEN shop.pgv_badge('active', 'success')
           ELSE shop.pgv_badge('inactive', 'danger') END
    );
  END LOOP;

  v_html := v_html || '</tbody></table></figure></main>';
  RETURN v_html;
END;
$function$;
