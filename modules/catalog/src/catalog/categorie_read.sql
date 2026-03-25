CREATE OR REPLACE FUNCTION catalog.categorie_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
  v_nb_articles int;
  v_has_children boolean;
BEGIN
  SELECT to_jsonb(c) || jsonb_build_object(
    'parent_nom', p.nom,
    'nb_articles', (SELECT count(*)::int FROM catalog.article a WHERE a.categorie_id = c.id)
  ) INTO v_result
  FROM catalog.categorie c
  LEFT JOIN catalog.categorie p ON p.id = c.parent_id
  WHERE c.id = p_id::int;

  IF v_result IS NULL THEN RETURN NULL; END IF;

  -- HATEOAS: delete only if no articles and no children
  v_nb_articles := (v_result->>'nb_articles')::int;
  v_has_children := EXISTS(SELECT 1 FROM catalog.categorie WHERE parent_id = p_id::int);

  IF v_nb_articles = 0 AND NOT v_has_children THEN
    v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
      jsonb_build_object('method', 'delete', 'uri', 'catalog://categorie/' || p_id)
    ));
  ELSE
    v_result := v_result || jsonb_build_object('actions', '[]'::jsonb);
  END IF;

  RETURN v_result;
END;
$function$;
