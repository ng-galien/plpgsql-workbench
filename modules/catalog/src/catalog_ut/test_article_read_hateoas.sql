CREATE OR REPLACE FUNCTION catalog_ut.test_article_read_hateoas()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_result jsonb;
  v_actions jsonb;
BEGIN
  INSERT INTO catalog.category (name) VALUES ('UT HATEOAS Cat') RETURNING id INTO v_id;
  INSERT INTO catalog.article (name, reference, category_id, sale_price, vat_rate, unit, active)
  VALUES ('UT HATEOAS Art', 'UT-HAT-01', v_id, 100.00, 20.00, 'u', true) RETURNING id INTO v_id;

  v_result := catalog.article_read(v_id::text);
  RETURN NEXT ok(v_result IS NOT NULL, 'article_read returns data');
  RETURN NEXT ok(v_result ? 'actions', 'article_read has actions');
  RETURN NEXT ok(v_result->'actions' @> '[{"method":"deactivate"}]'::jsonb, 'active article has deactivate action');
  RETURN NEXT ok(v_result->'actions' @> '[{"method":"delete"}]'::jsonb, 'active article has delete action');

  UPDATE catalog.article SET active = false WHERE id = v_id;
  v_result := catalog.article_read(v_id::text);
  v_actions := v_result->'actions';
  RETURN NEXT ok(v_actions @> '[{"method":"activate"}]'::jsonb, 'inactive article has activate action');
  RETURN NEXT ok(NOT v_actions @> '[{"method":"deactivate"}]'::jsonb, 'inactive article has no deactivate action');

  RETURN NEXT ok(v_result ? 'category_name', 'article_read has category_name');
  RETURN NEXT ok(v_result ? 'unit_label', 'article_read has unit_label');

  DELETE FROM catalog.article WHERE reference = 'UT-HAT-01';
  DELETE FROM catalog.category WHERE name = 'UT HATEOAS Cat';
END;
$function$;
