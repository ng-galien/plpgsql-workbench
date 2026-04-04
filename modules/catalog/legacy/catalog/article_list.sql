CREATE OR REPLACE FUNCTION catalog.article_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
    SELECT to_jsonb(a) || jsonb_build_object(
      'category_name', c.name,
      'unit_label', u.label
    )
    FROM catalog.article a
    LEFT JOIN catalog.category c ON c.id = a.category_id
    LEFT JOIN catalog.unit u ON u.code = a.unit
    WHERE p_filter IS NULL
       OR a.name ILIKE '%' || p_filter || '%'
       OR a.reference ILIKE '%' || p_filter || '%'
    ORDER BY a.name;
END;
$function$;
