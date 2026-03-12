CREATE OR REPLACE FUNCTION project_ut.test_chantier_lifecycle()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_statut text;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- Setup: get a client
  RETURN NEXT has_function('project', 'post_chantier_save', 'post_chantier_save exists');

  -- Create chantier
  PERFORM project.post_chantier_save(jsonb_build_object(
    'client_id', (SELECT id FROM crm.client LIMIT 1),
    'objet', 'Test chantier lifecycle'
  ));
  SELECT id INTO v_id FROM project.chantier WHERE objet = 'Test chantier lifecycle';
  RETURN NEXT ok(v_id IS NOT NULL, 'chantier created');

  SELECT statut INTO v_statut FROM project.chantier WHERE id = v_id;
  RETURN NEXT is(v_statut, 'preparation', 'initial status is preparation');

  -- Demarrer
  PERFORM project.post_chantier_demarrer(v_id);
  SELECT statut INTO v_statut FROM project.chantier WHERE id = v_id;
  RETURN NEXT is(v_statut, 'execution', 'status after demarrer is execution');

  -- Reception
  PERFORM project.post_chantier_reception(v_id);
  SELECT statut INTO v_statut FROM project.chantier WHERE id = v_id;
  RETURN NEXT is(v_statut, 'reception', 'status after reception');

  -- Clore
  PERFORM project.post_chantier_clore(v_id);
  SELECT statut INTO v_statut FROM project.chantier WHERE id = v_id;
  RETURN NEXT is(v_statut, 'clos', 'status after clore');

  -- Cleanup
  DELETE FROM project.chantier WHERE id = v_id;
END;
$function$;
