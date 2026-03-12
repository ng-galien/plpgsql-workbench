CREATE OR REPLACE FUNCTION stock_ut.test_mouvement_sortie()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_art_id int;
  v_dep_id int;
  v_qty numeric;
  v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  INSERT INTO stock.depot (nom, type, tenant_id) VALUES ('Test depot', 'atelier', 'test') RETURNING id INTO v_dep_id;
  INSERT INTO stock.article (reference, designation, categorie, pmp, tenant_id) VALUES ('TEST-S01', 'Sortie test', 'bois', 50.0000, 'test') RETURNING id INTO v_art_id;

  -- Entrée initiale
  INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, tenant_id)
  VALUES (v_art_id, v_dep_id, 'entree', 20, 50.00, 'test');

  -- Sortie
  v_result := stock.post_mouvement_save(jsonb_build_object(
    'type', 'sortie', 'article_id', v_art_id, 'depot_id', v_dep_id, 'quantite', '5'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'sortie success');

  SELECT coalesce(sum(quantite), 0) INTO v_qty FROM stock.mouvement WHERE article_id = v_art_id AND depot_id = v_dep_id;
  RETURN NEXT is(v_qty, 15::numeric, 'stock after sortie = 15');

  -- Sortie stock insuffisant
  v_result := stock.post_mouvement_save(jsonb_build_object(
    'type', 'sortie', 'article_id', v_art_id, 'depot_id', v_dep_id, 'quantite', '100'
  ));
  RETURN NEXT ok(v_result LIKE '%Stock insuffisant%', 'insufficient stock blocked');

  -- Cleanup
  DELETE FROM stock.mouvement WHERE tenant_id = 'test';
  DELETE FROM stock.article WHERE tenant_id = 'test';
  DELETE FROM stock.depot WHERE tenant_id = 'test';
END;
$function$;
