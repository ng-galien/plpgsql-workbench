CREATE OR REPLACE FUNCTION project_ut.test_post_pointage_note()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cid int;
  v_pid int;
  v_nid int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  INSERT INTO project.chantier (numero, client_id, objet, statut)
  VALUES ('CHT-UT-PN', (SELECT id FROM crm.client LIMIT 1), 'UT pointage/note', 'execution')
  RETURNING id INTO v_cid;

  -- Pointage ajouter
  PERFORM project.post_pointage_ajouter(v_cid, 7.5, 'Travail UT');
  SELECT id INTO v_pid FROM project.pointage WHERE chantier_id = v_cid;
  RETURN NEXT ok(v_pid IS NOT NULL, 'pointage created');
  RETURN NEXT is((SELECT heures FROM project.pointage WHERE id = v_pid), 7.5::numeric, 'heures saved');
  RETURN NEXT is((SELECT description FROM project.pointage WHERE id = v_pid), 'Travail UT', 'description saved');

  -- Pointage supprimer
  PERFORM project.post_pointage_supprimer(v_pid);
  RETURN NEXT ok(NOT EXISTS (SELECT 1 FROM project.pointage WHERE id = v_pid), 'pointage deleted');

  -- Note ajouter
  PERFORM project.post_note_ajouter(v_cid, 'Note UT test');
  SELECT id INTO v_nid FROM project.note_chantier WHERE chantier_id = v_cid;
  RETURN NEXT ok(v_nid IS NOT NULL, 'note created');
  RETURN NEXT is((SELECT contenu FROM project.note_chantier WHERE id = v_nid), 'Note UT test', 'contenu saved');

  -- Note supprimer
  PERFORM project.post_note_supprimer(v_nid);
  RETURN NEXT ok(NOT EXISTS (SELECT 1 FROM project.note_chantier WHERE id = v_nid), 'note deleted');

  -- Cannot add to clos chantier
  UPDATE project.chantier SET statut = 'clos' WHERE id = v_cid;
  RETURN NEXT throws_ok(
    format('SELECT project.post_pointage_ajouter(%s, 1, ''fail'')', v_cid),
    pgv.t('project.err_non_modifiable'),
    'cannot add pointage to clos'
  );
  RETURN NEXT throws_ok(
    format('SELECT project.post_note_ajouter(%s, ''fail'')', v_cid),
    pgv.t('project.err_non_modifiable'),
    'cannot add note to clos'
  );

  DELETE FROM project.chantier WHERE id = v_cid;
END;
$function$;
