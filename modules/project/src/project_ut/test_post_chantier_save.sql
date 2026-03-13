CREATE OR REPLACE FUNCTION project_ut.test_post_chantier_save()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client_id int;
  v_id int;
  v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  SELECT id INTO v_client_id FROM crm.client LIMIT 1;

  -- Create
  v_result := project.post_chantier_save(jsonb_build_object(
    'client_id', v_client_id, 'objet', 'UT save test', 'adresse', '1 rue Test'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'create returns success toast');

  SELECT id INTO v_id FROM project.chantier WHERE objet = 'UT save test';
  RETURN NEXT ok(v_id IS NOT NULL, 'chantier created');
  RETURN NEXT ok((SELECT numero FROM project.chantier WHERE id = v_id) LIKE 'CHT-%', 'numero auto-generated');
  RETURN NEXT is((SELECT adresse FROM project.chantier WHERE id = v_id), '1 rue Test', 'adresse saved');

  -- Update
  v_result := project.post_chantier_save(jsonb_build_object(
    'id', v_id, 'client_id', v_client_id, 'objet', 'UT save updated', 'adresse', '2 rue Test'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'update returns success toast');
  RETURN NEXT is((SELECT objet FROM project.chantier WHERE id = v_id), 'UT save updated', 'objet updated');

  -- Cannot update non-preparation/execution
  UPDATE project.chantier SET statut = 'clos' WHERE id = v_id;
  RETURN NEXT throws_ok(
    format('SELECT project.post_chantier_save(''{"id":%s,"client_id":%s,"objet":"fail"}''::jsonb)', v_id, v_client_id),
    pgv.t('project.err_seuls_modifiables'),
    'cannot update clos chantier'
  );

  DELETE FROM project.chantier WHERE id = v_id;
END;
$function$;
