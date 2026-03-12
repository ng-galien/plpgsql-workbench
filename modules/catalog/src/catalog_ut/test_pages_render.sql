CREATE OR REPLACE FUNCTION catalog_ut.test_pages_render()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_cat_id int;
  v_art_id int;
BEGIN
  -- Setup minimal data
  INSERT INTO catalog.categorie (nom) VALUES ('UT Render Cat') RETURNING id INTO v_cat_id;
  INSERT INTO catalog.article (designation, reference, categorie_id, prix_vente, unite, tva)
  VALUES ('UT Render Art', 'UT-REND-01', v_cat_id, 50.00, 'u', 20.00) RETURNING id INTO v_art_id;

  PERFORM set_config('pgv.route_prefix', '/catalog', true);

  -- get_index
  v_html := catalog.get_index();
  RETURN NEXT ok(v_html IS NOT NULL, 'get_index renders');
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'get_index has stats');

  -- get_articles
  v_html := catalog.get_articles();
  RETURN NEXT ok(v_html IS NOT NULL, 'get_articles renders');
  RETURN NEXT ok(v_html LIKE '%UT-REND-01%', 'get_articles shows test article');

  -- get_articles with search
  v_html := catalog.get_articles(jsonb_build_object('q', 'Render'));
  RETURN NEXT ok(v_html LIKE '%UT-REND-01%', 'get_articles search works');

  -- get_article
  v_html := catalog.get_article(v_art_id);
  RETURN NEXT ok(v_html IS NOT NULL, 'get_article renders');
  RETURN NEXT ok(v_html LIKE '%UT Render Art%', 'get_article shows designation');

  -- get_article_form (create)
  v_html := catalog.get_article_form();
  RETURN NEXT ok(v_html IS NOT NULL, 'get_article_form create renders');
  RETURN NEXT ok(v_html LIKE '%post_article_creer%', 'create form targets post_article_creer');

  -- get_article_form (edit)
  v_html := catalog.get_article_form(jsonb_build_object('p_id', v_art_id::text));
  RETURN NEXT ok(v_html IS NOT NULL, 'get_article_form edit renders');
  RETURN NEXT ok(v_html LIKE '%post_article_modifier%', 'edit form targets post_article_modifier');

  -- get_categories
  v_html := catalog.get_categories();
  RETURN NEXT ok(v_html IS NOT NULL, 'get_categories renders');
  RETURN NEXT ok(v_html LIKE '%UT Render Cat%', 'get_categories shows test category');

  -- article_options
  v_html := catalog.article_options();
  RETURN NEXT ok(v_html LIKE '%UT-REND-01%', 'article_options includes test article');

  -- Cleanup
  DELETE FROM catalog.article WHERE reference = 'UT-REND-01';
  DELETE FROM catalog.categorie WHERE nom = 'UT Render Cat';
END;
$function$;
