CREATE OR REPLACE FUNCTION stock.article_options(p_search text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN coalesce((
    SELECT jsonb_agg(row_to_json(r)::jsonb)
    FROM (
      SELECT
        a.id::text AS value,
        a.description AS label,
        a.reference || ' — ' || a.category || ' (' || a.unit || ')' AS detail
      FROM stock.article a
      WHERE a.active
        AND (p_search IS NULL OR p_search = ''
          OR a.description ILIKE '%' || p_search || '%'
          OR a.reference ILIKE '%' || p_search || '%')
      ORDER BY a.description
      LIMIT 20
    ) r
  ), '[]'::jsonb);
END;
$function$;
