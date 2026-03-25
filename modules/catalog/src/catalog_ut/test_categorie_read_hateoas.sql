CREATE OR REPLACE FUNCTION catalog_ut.test_categorie_read_hateoas()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cat_id int;
  v_art_id int;
  v_result jsonb;
BEGIN
  -- Empty category: delete allowed
  INSERT INTO catalog.categorie (nom) VALUES ('UT Empty Cat') RETURNING id INTO v_cat_id;
  v_result := catalog.categorie_read(v_cat_id::text);
  RETURN NEXT ok(v_result IS NOT NULL, 'categorie_read returns data');
  RETURN NEXT ok(v_result ? 'actions', 'categorie_read has actions');
  RETURN NEXT ok(v_result->'actions' @> '[{"method":"delete"}]'::jsonb, 'empty category has delete action');

  -- Category with article: no delete
  INSERT INTO catalog.article (designation, categorie_id) VALUES ('UT Cat Art', v_cat_id) RETURNING id INTO v_art_id;
  v_result := catalog.categorie_read(v_cat_id::text);
  RETURN NEXT is(jsonb_array_length(v_result->'actions'), 0, 'category with articles has no actions');

  -- Enriched fields
  RETURN NEXT ok(v_result ? 'nb_articles', 'categorie_read has nb_articles');
  RETURN NEXT is((v_result->>'nb_articles')::int, 1, 'nb_articles = 1');

  -- Cleanup
  DELETE FROM catalog.article WHERE id = v_art_id;
  DELETE FROM catalog.categorie WHERE id = v_cat_id;
END;
$function$;
