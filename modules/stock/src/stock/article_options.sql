CREATE OR REPLACE FUNCTION stock.article_options(p_search text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN coalesce((
    SELECT jsonb_agg(row_to_json(r)::jsonb)
    FROM (
      SELECT
        a.id::text AS value,
        a.designation AS label,
        a.reference || ' — ' || a.categorie || ' (' || a.unite || ')' AS detail
      FROM stock.article a
      WHERE a.active
        AND (p_search IS NULL OR p_search = ''
          OR a.designation ILIKE '%' || p_search || '%'
          OR a.reference ILIKE '%' || p_search || '%')
      ORDER BY a.designation
      LIMIT 20
    ) r
  ), '[]'::jsonb);
END;
$function$;
