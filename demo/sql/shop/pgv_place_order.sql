CREATE OR REPLACE FUNCTION shop.pgv_place_order(p_body jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
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
$function$;
