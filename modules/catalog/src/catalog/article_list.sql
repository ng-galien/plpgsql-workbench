CREATE OR REPLACE FUNCTION catalog.article_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
    SELECT to_jsonb(a) || jsonb_build_object(
      'categorie_nom', c.nom,
      'unite_label', u.label
    )
    FROM catalog.article a
    LEFT JOIN catalog.categorie c ON c.id = a.categorie_id
    LEFT JOIN catalog.unite u ON u.code = a.unite
    WHERE p_filter IS NULL
       OR a.designation ILIKE '%' || p_filter || '%'
       OR a.reference ILIKE '%' || p_filter || '%'
    ORDER BY a.designation;
END;
$function$;
