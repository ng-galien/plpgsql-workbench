CREATE OR REPLACE FUNCTION catalog_ut.test_category_read_hateoas()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cat_id int;
  v_art_id int;
  v_result jsonb;
BEGIN
  INSERT INTO catalog.category (name) VALUES ('UT Empty Cat') RETURNING id INTO v_cat_id;
  v_result := catalog.category_read(v_cat_id::text);
  RETURN NEXT ok(v_result IS NOT NULL, 'category_read returns data');
  RETURN NEXT ok(v_result ? 'actions', 'category_read has actions');
  RETURN NEXT ok(v_result->'actions' @> '[{"method":"delete"}]'::jsonb, 'empty category has delete action');

  INSERT INTO catalog.article (name, category_id) VALUES ('UT Cat Art', v_cat_id) RETURNING id INTO v_art_id;
  v_result := catalog.category_read(v_cat_id::text);
  RETURN NEXT is(jsonb_array_length(v_result->'actions'), 0, 'category with articles has no actions');

  RETURN NEXT ok(v_result ? 'article_count', 'category_read has article_count');
  RETURN NEXT is((v_result->>'article_count')::int, 1, 'article_count = 1');

  DELETE FROM catalog.article WHERE id = v_art_id;
  DELETE FROM catalog.category WHERE id = v_cat_id;
END;
$function$;
