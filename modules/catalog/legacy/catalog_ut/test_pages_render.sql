CREATE OR REPLACE FUNCTION catalog_ut.test_pages_render()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_cat_id int;
  v_art_id int;
BEGIN
  INSERT INTO catalog.category (name) VALUES ('UT Render Cat') RETURNING id INTO v_cat_id;
  INSERT INTO catalog.article (name, reference, category_id, sale_price, unit, vat_rate)
  VALUES ('UT Render Art', 'UT-REND-01', v_cat_id, 50.00, 'u', 20.00) RETURNING id INTO v_art_id;

  PERFORM set_config('pgv.route_prefix', '/catalog', true);

  v_html := catalog.get_index();
  RETURN NEXT ok(v_html IS NOT NULL, 'get_index renders');
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'get_index has stats');

  v_html := catalog.get_articles();
  RETURN NEXT ok(v_html IS NOT NULL, 'get_articles renders');
  RETURN NEXT ok(v_html LIKE '%UT-REND-01%', 'get_articles shows test article');

  v_html := catalog.get_articles(jsonb_build_object('q', 'Render'));
  RETURN NEXT ok(v_html LIKE '%UT-REND-01%', 'get_articles search works');

  v_html := catalog.get_article(v_art_id);
  RETURN NEXT ok(v_html IS NOT NULL, 'get_article renders');
  RETURN NEXT ok(v_html LIKE '%UT Render Art%', 'get_article shows name');

  v_html := catalog.get_article_form();
  RETURN NEXT ok(v_html IS NOT NULL, 'get_article_form create renders');
  RETURN NEXT ok(v_html LIKE '%post_article_create%', 'create form targets post_article_create');

  v_html := catalog.get_article_form(jsonb_build_object('p_id', v_art_id::text));
  RETURN NEXT ok(v_html IS NOT NULL, 'get_article_form edit renders');
  RETURN NEXT ok(v_html LIKE '%post_article_update%', 'edit form targets post_article_update');

  v_html := catalog.get_categories();
  RETURN NEXT ok(v_html IS NOT NULL, 'get_categories renders');
  RETURN NEXT ok(v_html LIKE '%UT Render Cat%', 'get_categories shows test category');

  v_html := catalog.article_options();
  RETURN NEXT ok(v_html LIKE '%UT-REND-01%', 'article_options includes test article');

  DELETE FROM catalog.article WHERE reference = 'UT-REND-01';
  DELETE FROM catalog.category WHERE name = 'UT Render Cat';
END;
$function$;
