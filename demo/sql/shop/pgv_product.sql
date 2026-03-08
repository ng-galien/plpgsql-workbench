CREATE OR REPLACE FUNCTION shop.pgv_product(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
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
$function$;
