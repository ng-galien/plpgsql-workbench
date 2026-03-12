CREATE OR REPLACE FUNCTION catalog_ut.test_post_article_modifier()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_art catalog.article;
  v_id int;
BEGIN
  -- Setup
  INSERT INTO catalog.article (reference, designation, prix_vente, tva, unite)
  VALUES ('UT-MOD-01', 'A modifier', 50.00, 20.00, 'u') RETURNING id INTO v_id;

  -- Full update
  v_result := catalog.post_article_modifier(jsonb_build_object(
    'id', v_id, 'designation', 'Modifié complet', 'reference', 'UT-MOD-01',
    'prix_vente', '120.00', 'prix_achat', '80.00', 'tva', '10.00', 'unite', 'h'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'full update success');

  SELECT * INTO v_art FROM catalog.article WHERE id = v_id;
  RETURN NEXT is(v_art.designation, 'Modifié complet', 'designation updated');
  RETURN NEXT is(v_art.prix_vente, 120.00::numeric(12,2), 'prix_vente updated');
  RETURN NEXT is(v_art.prix_achat, 80.00::numeric(12,2), 'prix_achat updated');
  RETURN NEXT is(v_art.tva, 10.00::numeric(4,2), 'tva updated');
  RETURN NEXT is(v_art.unite, 'h', 'unite updated');

  -- Toggle actif -> false
  v_result := catalog.post_article_modifier(jsonb_build_object('id', v_id, 'actif', 'false'));
  SELECT * INTO v_art FROM catalog.article WHERE id = v_id;
  RETURN NEXT ok(NOT v_art.actif, 'article deactivated');

  -- Toggle actif -> true
  v_result := catalog.post_article_modifier(jsonb_build_object('id', v_id, 'actif', 'true'));
  SELECT * INTO v_art FROM catalog.article WHERE id = v_id;
  RETURN NEXT ok(v_art.actif, 'article reactivated');

  -- Cleanup
  DELETE FROM catalog.article WHERE id = v_id;
END;
$function$;
