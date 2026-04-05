CREATE OR REPLACE FUNCTION stock_ut.test_get_valorisation()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_fournisseur_id int;
  v_depot_id int;
  v_art_id int;
  v_result text;
BEGIN
  -- Setup: fournisseur, depot, article with stock
  INSERT INTO crm.client (type, name) VALUES ('company', 'UT Valo Fournisseur')
  RETURNING id INTO v_fournisseur_id;

  INSERT INTO stock.depot (nom, type) VALUES ('UT Valo Entrepot', 'entrepot')
  RETURNING id INTO v_depot_id;

  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, pmp, fournisseur_id)
  VALUES ('UT-VALO-001', 'Tasseaux pin', 'bois', 'm', 2.50, 2.50, v_fournisseur_id)
  RETURNING id INTO v_art_id;

  -- Add stock
  INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, reference)
  VALUES (v_art_id, v_depot_id, 'entree', 100, 2.50, 'SEED-VALO');

  -- Test page renders
  v_result := stock.get_valorisation();
  RETURN NEXT ok(v_result IS NOT NULL, 'get_valorisation returns content');
  RETURN NEXT ok(v_result LIKE '%Valeur totale%', 'contains valeur totale stat');
  RETURN NEXT ok(v_result LIKE '%Par dépôt%', 'contains depot section');
  RETURN NEXT ok(v_result LIKE '%UT Valo Entrepot%', 'contains depot name');
  RETURN NEXT ok(v_result LIKE '%Par catégorie%', 'contains category section');
  RETURN NEXT ok(v_result LIKE '%bois%', 'contains bois category');

  -- Cleanup
  DELETE FROM stock.mouvement WHERE article_id = v_art_id;
  DELETE FROM stock.article WHERE id = v_art_id;
  DELETE FROM stock.depot WHERE id = v_depot_id;
  DELETE FROM crm.client WHERE id = v_fournisseur_id;
END;
$function$;
