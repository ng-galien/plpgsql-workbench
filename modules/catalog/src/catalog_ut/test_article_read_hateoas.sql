CREATE OR REPLACE FUNCTION catalog_ut.test_article_read_hateoas()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_result jsonb;
  v_actions jsonb;
BEGIN
  -- Setup
  INSERT INTO catalog.categorie (nom) VALUES ('UT HATEOAS Cat') RETURNING id INTO v_id;
  INSERT INTO catalog.article (designation, reference, categorie_id, prix_vente, tva, unite, actif)
  VALUES ('UT HATEOAS Art', 'UT-HAT-01', v_id, 100.00, 20.00, 'u', true) RETURNING id INTO v_id;

  -- Active article: deactivate + delete
  v_result := catalog.article_read(v_id::text);
  RETURN NEXT ok(v_result IS NOT NULL, 'article_read returns data');
  RETURN NEXT ok(v_result ? 'actions', 'article_read has actions');
  RETURN NEXT ok(v_result->'actions' @> '[{"method":"deactivate"}]'::jsonb, 'active article has deactivate action');
  RETURN NEXT ok(v_result->'actions' @> '[{"method":"delete"}]'::jsonb, 'active article has delete action');

  -- Deactivate
  UPDATE catalog.article SET actif = false WHERE id = v_id;
  v_result := catalog.article_read(v_id::text);
  v_actions := v_result->'actions';
  RETURN NEXT ok(v_actions @> '[{"method":"activate"}]'::jsonb, 'inactive article has activate action');
  RETURN NEXT ok(NOT v_actions @> '[{"method":"deactivate"}]'::jsonb, 'inactive article has no deactivate action');

  -- Enriched fields
  RETURN NEXT ok(v_result ? 'categorie_nom', 'article_read has categorie_nom');
  RETURN NEXT ok(v_result ? 'unite_label', 'article_read has unite_label');

  -- Cleanup
  DELETE FROM catalog.article WHERE reference = 'UT-HAT-01';
  DELETE FROM catalog.categorie WHERE nom = 'UT HATEOAS Cat';
END;
$function$;
