CREATE OR REPLACE FUNCTION shop.pgv_nav(p_path text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN format(
    '<nav class="container-fluid" style="border-bottom:1px solid var(--pico-muted-border-color);margin-bottom:2rem">
      <ul><li><strong>pgView Shop</strong></li></ul>
      <ul>
        <li><a href="/" %s>Dashboard</a></li>
        <li><a href="/products" %s>Products</a></li>
        <li><a href="/customers" %s>Customers</a></li>
        <li><a href="/orders" %s>Orders</a></li>
        <li><a href="/discounts" %s>Discounts</a></li>
        <li><a href="/graph" %s>Graph</a></li>
      </ul>
    </nav>',
    CASE WHEN p_path = '/' THEN 'aria-current="page"' ELSE '' END,
    CASE WHEN p_path LIKE '/products%' THEN 'aria-current="page"' ELSE '' END,
    CASE WHEN p_path LIKE '/customers%' THEN 'aria-current="page"' ELSE '' END,
    CASE WHEN p_path LIKE '/orders%' THEN 'aria-current="page"' ELSE '' END,
    CASE WHEN p_path LIKE '/discounts%' THEN 'aria-current="page"' ELSE '' END,
    CASE WHEN p_path = '/graph' THEN 'aria-current="page"' ELSE '' END
  );
END;
$function$;
