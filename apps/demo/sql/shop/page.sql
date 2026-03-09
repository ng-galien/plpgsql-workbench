CREATE OR REPLACE FUNCTION shop.page(p_path text, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
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
    WHEN p_path = '/discounts' THEN
      v_content := shop.pgv_discounts();
    WHEN p_path = '/graph' THEN
      v_content := shop.pgv_graph();
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
$function$;
