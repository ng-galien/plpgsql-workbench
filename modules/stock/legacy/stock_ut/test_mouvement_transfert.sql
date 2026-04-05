CREATE OR REPLACE FUNCTION stock_ut.test_mouvement_transfert()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_art_id int;
  v_dep_a int;
  v_dep_b int;
  v_qty_a numeric;
  v_qty_b numeric;
  v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  INSERT INTO stock.depot (nom, type, tenant_id) VALUES ('Depot A', 'atelier', 'test') RETURNING id INTO v_dep_a;
  INSERT INTO stock.depot (nom, type, tenant_id) VALUES ('Depot B', 'vehicule', 'test') RETURNING id INTO v_dep_b;
  INSERT INTO stock.article (reference, designation, categorie, pmp, tenant_id) VALUES ('TEST-T01', 'Transfert test', 'bois', 50.0000, 'test') RETURNING id INTO v_art_id;

  -- Stock initial
  INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, tenant_id)
  VALUES (v_art_id, v_dep_a, 'entree', 20, 50.00, 'test');

  -- Transfert A -> B
  v_result := stock.post_mouvement_save(jsonb_build_object(
    'type', 'transfert', 'article_id', v_art_id, 'depot_id', v_dep_a,
    'depot_destination_id', v_dep_b, 'quantite', '8'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'transfert success');

  SELECT coalesce(sum(quantite), 0) INTO v_qty_a FROM stock.mouvement WHERE article_id = v_art_id AND depot_id = v_dep_a;
  SELECT coalesce(sum(quantite), 0) INTO v_qty_b FROM stock.mouvement WHERE article_id = v_art_id AND depot_id = v_dep_b;
  RETURN NEXT is(v_qty_a, 12::numeric, 'depot A stock = 12');
  RETURN NEXT is(v_qty_b, 8::numeric, 'depot B stock = 8');

  -- Transfert same depot blocked
  v_result := stock.post_mouvement_save(jsonb_build_object(
    'type', 'transfert', 'article_id', v_art_id, 'depot_id', v_dep_a,
    'depot_destination_id', v_dep_a, 'quantite', '5'
  ));
  RETURN NEXT ok(v_result LIKE '%identiques%', 'same depot blocked');

  -- Cleanup
  DELETE FROM stock.mouvement WHERE tenant_id = 'test';
  DELETE FROM stock.article WHERE tenant_id = 'test';
  DELETE FROM stock.depot WHERE tenant_id = 'test';
END;
$function$;
