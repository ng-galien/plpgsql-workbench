CREATE OR REPLACE FUNCTION shop.get_catalog(p_search text DEFAULT NULL::text, p_in_stock_only boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'products', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'name', p.name,
        'price', p.price,
        'stock', p.stock,
        'available', p.stock > 0
      ) ORDER BY p.name
    ), '[]'::jsonb),
    'total', count(*),
    'in_stock', count(*) FILTER (WHERE p.stock > 0)
  ) INTO v_result
  FROM shop.products p
  WHERE (p_search IS NULL OR p.name ILIKE '%' || p_search || '%')
    AND (NOT p_in_stock_only OR p.stock > 0);

  RETURN v_result;
END;
$function$;
