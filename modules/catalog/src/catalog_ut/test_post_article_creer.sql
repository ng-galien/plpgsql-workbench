CREATE OR REPLACE FUNCTION catalog_ut.test_post_article_creer()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_art catalog.article;
  v_id int;
BEGIN
  -- Create
  v_result := catalog.post_article_creer(jsonb_build_object(
    'reference', 'UT-ART-01', 'designation', 'Article test UT',
    'prix_vente', '100.00', 'prix_achat', '60.00', 'tva', '20.00', 'unite', 'u'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'create returns success toast');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'create returns redirect');

  SELECT * INTO v_art FROM catalog.article WHERE reference = 'UT-ART-01';
  RETURN NEXT ok(FOUND, 'article created in DB');
  RETURN NEXT is(v_art.designation, 'Article test UT', 'designation saved');
  RETURN NEXT is(v_art.prix_vente, 100.00::numeric(12,2), 'prix_vente saved');
  RETURN NEXT is(v_art.prix_achat, 60.00::numeric(12,2), 'prix_achat saved');
  RETURN NEXT is(v_art.tva, 20.00::numeric(4,2), 'tva saved');
  RETURN NEXT is(v_art.unite, 'u', 'unite saved');
  RETURN NEXT ok(v_art.actif, 'article actif by default');

  -- Cleanup
  DELETE FROM catalog.article WHERE reference = 'UT-ART-01';
END;
$function$;
