CREATE OR REPLACE FUNCTION project_ut.test_post_chantier_supprimer()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_client_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  SELECT id INTO v_client_id FROM crm.client LIMIT 1;

  -- Create chantier in preparation
  INSERT INTO project.chantier (numero, client_id, objet)
  VALUES ('CHT-UT-DEL', v_client_id, 'UT delete test')
  RETURNING id INTO v_id;

  -- Cannot delete non-preparation
  UPDATE project.chantier SET statut = 'execution' WHERE id = v_id;
  RETURN NEXT throws_ok(
    format('SELECT project.post_chantier_supprimer(%s)', v_id),
    'Seuls les chantiers en préparation peuvent être supprimés',
    'cannot delete execution chantier'
  );

  -- Can delete preparation
  UPDATE project.chantier SET statut = 'preparation' WHERE id = v_id;
  PERFORM project.post_chantier_supprimer(v_id);
  RETURN NEXT ok(NOT EXISTS (SELECT 1 FROM project.chantier WHERE id = v_id), 'chantier deleted');
END;
$function$;
