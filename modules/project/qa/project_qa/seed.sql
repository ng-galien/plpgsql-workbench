CREATE OR REPLACE FUNCTION project_qa.seed()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client1 int;
  v_client2 int;
  v_client3 int;
  v_devis_id int;
  v_devis2_id int;
  v_c1 int;
  v_c2 int;
  v_c3 int;
  v_c4 int;
  v_c5 int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- Cleanup
  DELETE FROM project.note_chantier;
  DELETE FROM project.pointage;
  DELETE FROM project.jalon;
  DELETE FROM project.chantier;

  -- Recuperer clients CRM
  SELECT id INTO v_client1 FROM crm.client ORDER BY id LIMIT 1;
  SELECT id INTO v_client2 FROM crm.client ORDER BY id LIMIT 1 OFFSET 1;
  SELECT id INTO v_client3 FROM crm.client ORDER BY id LIMIT 1 OFFSET 2;
  IF v_client2 IS NULL THEN v_client2 := v_client1; END IF;
  IF v_client3 IS NULL THEN v_client3 := v_client1; END IF;

  -- Recuperer devis acceptes si disponibles
  SELECT id INTO v_devis_id FROM quote.devis WHERE statut = 'accepte' LIMIT 1;
  SELECT id INTO v_devis2_id FROM quote.devis WHERE statut = 'accepte' LIMIT 1 OFFSET 1;
  IF v_devis2_id IS NULL THEN v_devis2_id := v_devis_id; END IF;

  -- Chantier 1: en cours (execution), 55% avancement, lié à devis
  INSERT INTO project.chantier (numero, client_id, devis_id, objet, adresse, statut, date_debut, date_fin_prevue, notes)
  VALUES ('CHT-2026-001', v_client1, v_devis_id, 'Rénovation salle de bain',
          '12 rue des Lilas, 69003 Lyon', 'execution',
          '2026-02-15', '2026-04-15',
          'Accès chantier : code 4521B. Voisin prévenu.')
  RETURNING id INTO v_c1;

  INSERT INTO project.jalon (chantier_id, sort_order, label, pct_avancement, statut, date_prevue, date_reelle) VALUES
    (v_c1, 1, 'Démolition', 100, 'valide', '2026-02-20', '2026-02-19'),
    (v_c1, 2, 'Plomberie', 100, 'valide', '2026-03-01', '2026-03-02'),
    (v_c1, 3, 'Carrelage', 75, 'en_cours', '2026-03-15', NULL),
    (v_c1, 4, 'Électricité', 0, 'a_faire', '2026-03-25', NULL),
    (v_c1, 5, 'Finitions', 0, 'a_faire', '2026-04-10', NULL);

  INSERT INTO project.pointage (chantier_id, date_pointage, heures, description) VALUES
    (v_c1, '2026-02-15', 8, 'Préparation chantier, bâchage'),
    (v_c1, '2026-02-16', 7.5, 'Démolition carrelage sol'),
    (v_c1, '2026-02-17', 8, 'Démolition murale + évacuation'),
    (v_c1, '2026-02-19', 6, 'Fin démo, nettoyage'),
    (v_c1, '2026-03-01', 8, 'Tuyauterie cuivre'),
    (v_c1, '2026-03-02', 7, 'Raccordements, test pression'),
    (v_c1, '2026-03-08', 8, 'Pose receveur douche'),
    (v_c1, '2026-03-09', 8, 'Carrelage sol début'),
    (v_c1, '2026-03-10', 7.5, 'Carrelage sol suite'),
    (v_c1, '2026-03-11', 8, 'Carrelage mural début');

  INSERT INTO project.note_chantier (chantier_id, contenu, created_at) VALUES
    (v_c1, 'Fuite découverte derrière le mur porteur — réparation incluse.', '2026-02-17 10:30:00+01'),
    (v_c1, 'Client demande changement coloris carrelage mural (gris -> blanc).', '2026-03-05 14:00:00+01'),
    (v_c1, 'Livraison robinetterie prévue semaine 12.', '2026-03-10 09:00:00+01');

  -- Chantier 2: en preparation
  INSERT INTO project.chantier (numero, client_id, objet, adresse, statut, date_debut, date_fin_prevue, notes)
  VALUES ('CHT-2026-002', v_client2, 'Extension garage',
          '45 avenue Jean Moulin, 69005 Lyon', 'preparation',
          '2026-04-01', '2026-06-30',
          'Attente permis de construire.')
  RETURNING id INTO v_c2;

  INSERT INTO project.jalon (chantier_id, sort_order, label, date_prevue) VALUES
    (v_c2, 1, 'Terrassement', '2026-04-05'),
    (v_c2, 2, 'Fondations', '2026-04-15'),
    (v_c2, 3, 'Maçonnerie', '2026-05-10'),
    (v_c2, 4, 'Charpente / Toiture', '2026-05-25'),
    (v_c2, 5, 'Électricité / Finitions', '2026-06-20');

  -- Chantier 3: en reception, 95%
  INSERT INTO project.chantier (numero, client_id, devis_id, objet, adresse, statut, date_debut, date_fin_prevue, notes)
  VALUES ('CHT-2026-003', v_client3, v_devis2_id, 'Aménagement bureau professionnel',
          '8 place Bellecour, 69002 Lyon', 'reception',
          '2026-01-10', '2026-03-01',
          'Bureau open space + salle de réunion.')
  RETURNING id INTO v_c3;

  INSERT INTO project.jalon (chantier_id, sort_order, label, pct_avancement, statut, date_prevue, date_reelle) VALUES
    (v_c3, 1, 'Cloisons', 100, 'valide', '2026-01-20', '2026-01-18'),
    (v_c3, 2, 'Électricité / Réseau', 100, 'valide', '2026-02-01', '2026-02-03'),
    (v_c3, 3, 'Peinture', 100, 'valide', '2026-02-10', '2026-02-09'),
    (v_c3, 4, 'Mobilier / Agencement', 100, 'valide', '2026-02-20', '2026-02-22'),
    (v_c3, 5, 'Réserves levée', 75, 'en_cours', '2026-03-01', NULL);

  INSERT INTO project.pointage (chantier_id, date_pointage, heures, description) VALUES
    (v_c3, '2026-01-10', 8, 'Traçage + pose rails'),
    (v_c3, '2026-01-11', 8, 'Pose plaques BA13'),
    (v_c3, '2026-01-15', 7, 'Bandes + enduit'),
    (v_c3, '2026-02-01', 8, 'Tirage câbles'),
    (v_c3, '2026-02-03', 6, 'Pose prises + interrupteurs'),
    (v_c3, '2026-02-09', 8, 'Peinture 2 couches'),
    (v_c3, '2026-02-22', 7, 'Montage mobilier');

  INSERT INTO project.note_chantier (chantier_id, contenu, created_at) VALUES
    (v_c3, 'Réserve : prise réseau bureau 3 non fonctionnelle.', '2026-02-25 11:00:00+01'),
    (v_c3, 'Client satisfait de l''agencement global.', '2026-02-28 16:00:00+01');

  -- Chantier 4: EN RETARD (execution, date_fin_prevue dépassée)
  INSERT INTO project.chantier (numero, client_id, objet, adresse, statut, date_debut, date_fin_prevue, notes)
  VALUES ('CHT-2026-004', v_client1, 'Ravalement façade immeuble',
          '22 rue Victor Hugo, 69002 Lyon', 'execution',
          '2025-11-01', '2026-02-28',
          'Retard dû aux intempéries janvier.')
  RETURNING id INTO v_c4;

  INSERT INTO project.jalon (chantier_id, sort_order, label, pct_avancement, statut, date_prevue, date_reelle) VALUES
    (v_c4, 1, 'Échafaudage', 100, 'valide', '2025-11-10', '2025-11-12'),
    (v_c4, 2, 'Nettoyage façade', 100, 'valide', '2025-12-01', '2025-12-05'),
    (v_c4, 3, 'Réparation fissures', 50, 'en_cours', '2026-01-15', NULL),
    (v_c4, 4, 'Enduit + peinture', 0, 'a_faire', '2026-02-15', NULL);

  INSERT INTO project.pointage (chantier_id, date_pointage, heures, description) VALUES
    (v_c4, '2025-11-01', 8, 'Montage échafaudage'),
    (v_c4, '2025-11-12', 8, 'Nettoyage haute pression'),
    (v_c4, '2025-12-05', 7, 'Diagnostic fissures'),
    (v_c4, '2026-01-10', 8, 'Rebouchage fissures niveau 1');

  INSERT INTO project.note_chantier (chantier_id, contenu, created_at) VALUES
    (v_c4, 'Arrêt chantier 3 semaines (gel, neige).', '2026-01-20 09:00:00+01'),
    (v_c4, 'Reprise prévue dès que météo favorable.', '2026-02-10 14:00:00+01');

  -- Chantier 5: CLOS (terminé)
  INSERT INTO project.chantier (numero, client_id, objet, adresse, statut, date_debut, date_fin_prevue, date_fin_reelle, notes)
  VALUES ('CHT-2025-005', v_client2, 'Installation cuisine équipée',
          '3 impasse des Cerisiers, 69008 Lyon', 'clos',
          '2025-10-01', '2025-12-15', '2025-12-10',
          'Livré en avance. Client très satisfait.')
  RETURNING id INTO v_c5;

  INSERT INTO project.jalon (chantier_id, sort_order, label, pct_avancement, statut, date_prevue, date_reelle) VALUES
    (v_c5, 1, 'Démontage ancienne cuisine', 100, 'valide', '2025-10-05', '2025-10-04'),
    (v_c5, 2, 'Plomberie / Électricité', 100, 'valide', '2025-10-20', '2025-10-18'),
    (v_c5, 3, 'Pose meubles', 100, 'valide', '2025-11-15', '2025-11-12'),
    (v_c5, 4, 'Plan de travail + crédence', 100, 'valide', '2025-12-01', '2025-11-28'),
    (v_c5, 5, 'Électroménager + finitions', 100, 'valide', '2025-12-10', '2025-12-10');

  INSERT INTO project.pointage (chantier_id, date_pointage, heures, description) VALUES
    (v_c5, '2025-10-01', 8, 'Démontage ancien plan'),
    (v_c5, '2025-10-04', 7, 'Évacuation + nettoyage'),
    (v_c5, '2025-10-18', 8, 'Raccordements'),
    (v_c5, '2025-11-12', 8, 'Pose caissons'),
    (v_c5, '2025-11-28', 7, 'Plan de travail granit'),
    (v_c5, '2025-12-10', 6, 'Finitions + ménage');

  RETURN 'project_qa.seed: 5 chantiers (execution/preparation/reception/retard/clos) + jalons + pointages + notes';
END;
$function$;
