CREATE OR REPLACE FUNCTION project_ut.test_post_jalon_actions()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cid int;
  v_jid int;
  v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  INSERT INTO project.chantier (numero, client_id, objet, statut)
  VALUES ('CHT-UT-JAL', (SELECT id FROM crm.client LIMIT 1), 'UT jalon test', 'execution')
  RETURNING id INTO v_cid;

  -- Ajouter
  v_result := project.post_jalon_ajouter(v_cid, 'Jalon UT');
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'jalon ajouter returns toast');
  SELECT id INTO v_jid FROM project.jalon WHERE chantier_id = v_cid AND label = 'Jalon UT';
  RETURN NEXT ok(v_jid IS NOT NULL, 'jalon created');
  RETURN NEXT is((SELECT pct_avancement FROM project.jalon WHERE id = v_jid), 0::numeric, 'initial pct is 0');

  -- Avancer
  PERFORM project.post_jalon_avancer(v_jid, 50);
  RETURN NEXT is((SELECT pct_avancement FROM project.jalon WHERE id = v_jid), 50::numeric, 'pct updated to 50');
  RETURN NEXT is((SELECT statut FROM project.jalon WHERE id = v_jid), 'en_cours', 'statut auto en_cours');

  -- Avancer to 100 -> auto valide
  PERFORM project.post_jalon_avancer(v_jid, 100);
  RETURN NEXT is((SELECT statut FROM project.jalon WHERE id = v_jid), 'valide', 'pct 100 -> auto valide');

  -- Supprimer
  PERFORM project.post_jalon_supprimer(v_jid);
  RETURN NEXT ok(NOT EXISTS (SELECT 1 FROM project.jalon WHERE id = v_jid), 'jalon deleted');

  -- Cannot add to clos chantier
  UPDATE project.chantier SET statut = 'clos' WHERE id = v_cid;
  RETURN NEXT throws_ok(
    format('SELECT project.post_jalon_ajouter(%s, ''test'')', v_cid),
    pgv.t('project.err_non_modifiable'),
    'cannot add jalon to clos chantier'
  );

  DELETE FROM project.chantier WHERE id = v_cid;
END;
$function$;
