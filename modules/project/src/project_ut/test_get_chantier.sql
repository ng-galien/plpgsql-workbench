CREATE OR REPLACE FUNCTION project_ut.test_get_chantier()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_cli_id int;
  v_dev_id int;
  v_ch_id  int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  PERFORM set_config('pgv.route_prefix', '/project', true);

  -- Seed
  INSERT INTO crm.client(type, name, email, tenant_id) VALUES ('individual', 'CovCli', 'cov@test.com', 'dev') RETURNING id INTO v_cli_id;
  INSERT INTO quote.devis(numero, client_id, objet, tenant_id) VALUES ('DEV-COV-001', v_cli_id, 'Devis cov', 'dev') RETURNING id INTO v_dev_id;
  INSERT INTO project.chantier(numero, client_id, devis_id, objet, adresse, statut, date_debut, date_fin_prevue, tenant_id)
    VALUES ('CHT-COV-001', v_cli_id, v_dev_id, 'Objet cov', '1 rue Test', 'preparation', CURRENT_DATE, CURRENT_DATE + 30, 'dev')
    RETURNING id INTO v_ch_id;
  INSERT INTO project.jalon(chantier_id, sort_order, label, tenant_id) VALUES (v_ch_id, 1, 'Jalon cov', 'dev');
  INSERT INTO project.pointage(chantier_id, heures, description, tenant_id) VALUES (v_ch_id, 2.5, 'Pointage cov', 'dev');
  INSERT INTO project.note_chantier(chantier_id, contenu, tenant_id) VALUES (v_ch_id, 'Note cov', 'dev');

  -- Not found
  v_html := project.get_chantier(-1);
  RETURN NEXT ok(v_html LIKE '%introuvable%', 'not found renders empty');

  -- Preparation statut: has demarrer, modifier, supprimer
  v_html := project.get_chantier(v_ch_id);
  RETURN NEXT ok(v_html IS NOT NULL AND length(v_html) > 100, 'preparation renders');
  RETURN NEXT ok(v_html LIKE '%post_chantier_demarrer%', 'preparation has demarrer action');
  RETURN NEXT ok(v_html LIKE '%post_chantier_supprimer%', 'preparation has supprimer action');
  RETURN NEXT ok(v_html LIKE '%Modifier%', 'preparation has modifier link');
  RETURN NEXT ok(v_html LIKE '%/crm/client%', 'has crm link');
  RETURN NEXT ok(v_html LIKE '%DEV-COV-001%', 'has devis link');
  RETURN NEXT ok(v_html LIKE '%pgv-tabs%', 'has tabs');
  RETURN NEXT ok(v_html LIKE '%Jalon cov%', 'shows jalon');
  RETURN NEXT ok(v_html LIKE '%2.5%', 'shows pointage heures');
  RETURN NEXT ok(v_html LIKE '%Note cov%', 'shows note');
  RETURN NEXT ok(v_html LIKE '%post_jalon_ajouter%', 'has jalon form');
  RETURN NEXT ok(v_html LIKE '%post_pointage_ajouter%', 'has pointage form');
  RETURN NEXT ok(v_html LIKE '%post_note_ajouter%', 'has note form');

  -- Execution statut: has reception, modifier, no supprimer
  UPDATE project.chantier SET statut = 'execution' WHERE id = v_ch_id;
  v_html := project.get_chantier(v_ch_id);
  RETURN NEXT ok(v_html LIKE '%post_chantier_reception%', 'execution has reception action');
  RETURN NEXT ok(v_html NOT LIKE '%post_chantier_supprimer%', 'execution no supprimer');

  -- Reception statut: has clore only
  UPDATE project.chantier SET statut = 'reception' WHERE id = v_ch_id;
  v_html := project.get_chantier(v_ch_id);
  RETURN NEXT ok(v_html LIKE '%post_chantier_clore%', 'reception has clore action');
  RETURN NEXT ok(v_html NOT LIKE '%post_chantier_demarrer%', 'reception no demarrer');

  -- Clos statut: no actions, no forms
  UPDATE project.chantier SET statut = 'clos', date_fin_reelle = CURRENT_DATE WHERE id = v_ch_id;
  v_html := project.get_chantier(v_ch_id);
  RETURN NEXT ok(v_html NOT LIKE '%post_chantier_demarrer%', 'clos no demarrer');
  RETURN NEXT ok(v_html NOT LIKE '%post_jalon_ajouter%', 'clos no jalon form');

  -- No devis branch
  UPDATE project.chantier SET devis_id = NULL WHERE id = v_ch_id;
  v_html := project.get_chantier(v_ch_id);
  RETURN NEXT ok(v_html NOT LIKE '%DEV-COV-001%', 'no devis shows dash');

  -- No address branch
  UPDATE project.chantier SET adresse = '' WHERE id = v_ch_id;
  v_html := project.get_chantier(v_ch_id);
  RETURN NEXT ok(v_html IS NOT NULL, 'empty address renders');

  -- Cleanup
  DELETE FROM project.note_chantier WHERE chantier_id = v_ch_id;
  DELETE FROM project.pointage WHERE chantier_id = v_ch_id;
  DELETE FROM project.jalon WHERE chantier_id = v_ch_id;
  DELETE FROM project.chantier WHERE id = v_ch_id;
  DELETE FROM quote.devis WHERE id = v_dev_id;
  DELETE FROM crm.client WHERE id = v_cli_id;
END;
$function$;
