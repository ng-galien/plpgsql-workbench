CREATE OR REPLACE FUNCTION stock_ut.test_post_depot_save()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_dep stock.depot;
  v_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Create
  v_result := stock.post_depot_save(jsonb_build_object(
    'nom', 'Dépôt test', 'type', 'atelier', 'adresse', '1 rue Test'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'create returns success');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'create returns redirect');

  SELECT id INTO v_id FROM stock.depot WHERE nom = 'Dépôt test' AND tenant_id = 'test';
  SELECT * INTO v_dep FROM stock.depot WHERE id = v_id;
  RETURN NEXT ok(FOUND, 'depot created in DB');
  RETURN NEXT is(v_dep.type, 'atelier', 'type saved');
  RETURN NEXT is(v_dep.adresse, '1 rue Test', 'adresse saved');

  -- Update
  v_result := stock.post_depot_save(jsonb_build_object(
    'id', v_id, 'nom', 'Dépôt modifié', 'type', 'chantier', 'adresse', '2 rue Modif'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'update returns success');

  SELECT * INTO v_dep FROM stock.depot WHERE id = v_id;
  RETURN NEXT is(v_dep.nom, 'Dépôt modifié', 'nom updated');
  RETURN NEXT is(v_dep.type, 'chantier', 'type updated');

  -- Cleanup
  DELETE FROM stock.depot WHERE tenant_id = 'test';
END;
$function$;
