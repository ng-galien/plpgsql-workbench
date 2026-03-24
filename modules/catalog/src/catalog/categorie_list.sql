CREATE OR REPLACE FUNCTION catalog.categorie_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
    SELECT to_jsonb(c) || jsonb_build_object(
      'parent_nom', p.nom,
      'nb_articles', (SELECT count(*)::int FROM catalog.article a WHERE a.categorie_id = c.id)
    )
    FROM catalog.categorie c
    LEFT JOIN catalog.categorie p ON p.id = c.parent_id
    WHERE p_filter IS NULL
       OR c.nom ILIKE '%' || p_filter || '%'
    ORDER BY COALESCE(p.nom, c.nom), c.nom;
END;
$function$;
