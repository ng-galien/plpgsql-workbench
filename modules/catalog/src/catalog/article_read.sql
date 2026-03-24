CREATE OR REPLACE FUNCTION catalog.article_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN (
    SELECT to_jsonb(a) || jsonb_build_object(
      'categorie_nom', c.nom,
      'unite_label', u.label
    )
    FROM catalog.article a
    LEFT JOIN catalog.categorie c ON c.id = a.categorie_id
    LEFT JOIN catalog.unite u ON u.code = a.unite
    WHERE a.id = p_id::int
  );
END;
$function$;
