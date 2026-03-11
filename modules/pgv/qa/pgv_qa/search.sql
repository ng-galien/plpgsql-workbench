CREATE OR REPLACE FUNCTION pgv_qa.search(p_query text, p_limit integer DEFAULT 12, p_offset integer DEFAULT 0)
 RETURNS SETOF pgv.search_result
 LANGUAGE sql
 STABLE
AS $function$
  SELECT
    ROW(
      '/items?id=' || id,
      CASE status WHEN 'draft' THEN '📝' WHEN 'classified' THEN '📁' WHEN 'archived' THEN '🗄️' ELSE '📄' END,
      status,
      name,
      'Item #' || id || ' — ' || to_char(created_at, 'DD/MM/YYYY'),
      CASE
        WHEN lower(name) = lower(p_query) THEN 1.0
        WHEN lower(name) LIKE lower(p_query) || '%' THEN 0.8
        ELSE 0.5
      END::real
    )::pgv.search_result
  FROM pgv_qa.item
  WHERE lower(name) LIKE '%' || lower(p_query) || '%'
  ORDER BY
    CASE
      WHEN lower(name) = lower(p_query) THEN 1.0
      WHEN lower(name) LIKE lower(p_query) || '%' THEN 0.8
      ELSE 0.5
    END DESC,
    name
  LIMIT p_limit
  OFFSET p_offset;
$function$;
