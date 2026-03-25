CREATE OR REPLACE FUNCTION catalog.category_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
    SELECT to_jsonb(c) || jsonb_build_object(
      'parent_name', p.name,
      'article_count', (SELECT count(*)::int FROM catalog.article a WHERE a.category_id = c.id)
    )
    FROM catalog.category c
    LEFT JOIN catalog.category p ON p.id = c.parent_id
    WHERE p_filter IS NULL
       OR c.name ILIKE '%' || p_filter || '%'
    ORDER BY COALESCE(p.name, c.name), c.name;
END;
$function$;
