CREATE OR REPLACE FUNCTION shop.pgv_products()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_md text;
  r record;
BEGIN
  v_html := '<main class="container">';
  v_html := v_html || '<hgroup><h2>Products</h2><p>Catalog</p></hgroup>';

  v_md := E'| Name | Price | Stock |\n| --- | --- | --- |\n';
  FOR r IN SELECT * FROM shop.products ORDER BY name
  LOOP
    v_md := v_md || format(E'| <a href="/products/%s">%s</a> | %s | %s |\n',
      r.id, shop.esc(r.name), shop.pgv_money(r.price),
      CASE WHEN r.stock > 10 THEN shop.pgv_badge(r.stock || '', 'success')
           WHEN r.stock > 0  THEN shop.pgv_badge(r.stock || '', 'warning')
           ELSE shop.pgv_badge('Out of stock', 'danger') END);
  END LOOP;

  v_html := v_html || '<figure><md>' || v_md || '</md></figure></main>';
  RETURN v_html;
END;
$function$;
