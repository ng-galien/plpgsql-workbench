CREATE OR REPLACE FUNCTION stock_ut.test_mouvement_entree()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_art_id int;
  v_dep_id int;
  v_qty numeric;
  v_pmp numeric;
  v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  INSERT INTO stock.depot (nom, type, tenant_id) VALUES ('Test depot', 'atelier', 'test') RETURNING id INTO v_dep_id;
  INSERT INTO stock.article (reference, designation, categorie, tenant_id) VALUES ('TEST-E01', 'Entrée test', 'bois', 'test') RETURNING id INTO v_art_id;

  -- Entrée via post_mouvement_save
  v_result := stock.post_mouvement_save(jsonb_build_object(
    'type', 'entree', 'article_id', v_art_id, 'depot_id', v_dep_id,
    'quantite', '10', 'prix_unitaire', '50'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'entry success toast');

  SELECT coalesce(sum(quantite), 0) INTO v_qty FROM stock.mouvement WHERE article_id = v_art_id AND depot_id = v_dep_id;
  RETURN NEXT is(v_qty, 10::numeric, 'stock after entry = 10');

  SELECT pmp INTO v_pmp FROM stock.article WHERE id = v_art_id;
  RETURN NEXT is(v_pmp, 50.0000::numeric(12,4), 'PMP = 50 after first entry');

  -- Second entry at different price
  v_result := stock.post_mouvement_save(jsonb_build_object(
    'type', 'entree', 'article_id', v_art_id, 'depot_id', v_dep_id,
    'quantite', '10', 'prix_unitaire', '70'
  ));

  SELECT pmp INTO v_pmp FROM stock.article WHERE id = v_art_id;
  RETURN NEXT is(v_pmp, 60.0000::numeric(12,4), 'PMP = 60 after weighted avg');

  SELECT coalesce(sum(quantite), 0) INTO v_qty FROM stock.mouvement WHERE article_id = v_art_id;
  RETURN NEXT is(v_qty, 20::numeric, 'total stock = 20');

  -- Cleanup
  DELETE FROM stock.mouvement WHERE tenant_id = 'test';
  DELETE FROM stock.article WHERE tenant_id = 'test';
  DELETE FROM stock.depot WHERE tenant_id = 'test';
END;
$function$;
