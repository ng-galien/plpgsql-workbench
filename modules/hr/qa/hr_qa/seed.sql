CREATE OR REPLACE FUNCTION hr_qa.seed()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_e1 int; v_e2 int; v_e3 int; v_e4 int; v_e5 int; v_e6 int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- Clean existing QA data
  DELETE FROM hr.employee WHERE nom IN (
    'Dupont', 'Martin', 'Lefebvre', 'Moreau', 'Rousseau', 'Garcia'
  ) AND prenom IN ('Marie', 'Thomas', 'Claire', 'Lucas', 'Emma', 'Antoine');

  -- 6 salariés réalistes
  INSERT INTO hr.employee (nom, prenom, email, phone, matricule, date_naissance, poste, departement, type_contrat, date_embauche, heures_hebdo, notes)
  VALUES ('Dupont', 'Marie', 'marie.dupont@entreprise.fr', '06 12 34 56 78', 'EMP-001', '1988-03-15', 'Chef de chantier', 'Production', 'cdi', '2020-09-01', 39, 'Responsable chantiers zone Lyon')
  RETURNING id INTO v_e1;

  INSERT INTO hr.employee (nom, prenom, email, phone, matricule, date_naissance, poste, departement, type_contrat, date_embauche, heures_hebdo)
  VALUES ('Martin', 'Thomas', 'thomas.martin@entreprise.fr', '06 23 45 67 89', 'EMP-002', '1995-07-22', 'Charpentier', 'Production', 'cdi', '2022-03-15', 35)
  RETURNING id INTO v_e2;

  INSERT INTO hr.employee (nom, prenom, email, phone, matricule, date_naissance, poste, departement, type_contrat, date_embauche, heures_hebdo, notes)
  VALUES ('Lefebvre', 'Claire', 'claire.lefebvre@entreprise.fr', '06 34 56 78 90', 'EMP-003', '1992-11-08', 'Comptable', 'Administration', 'cdi', '2019-01-07', 35, 'Gère aussi la paie')
  RETURNING id INTO v_e3;

  INSERT INTO hr.employee (nom, prenom, email, matricule, date_naissance, poste, departement, type_contrat, date_embauche, date_fin, heures_hebdo)
  VALUES ('Moreau', 'Lucas', 'lucas.moreau@entreprise.fr', 'EMP-004', '2001-05-30', 'Apprenti couvreur', 'Production', 'alternance', '2025-09-01', '2027-08-31', 35)
  RETURNING id INTO v_e4;

  INSERT INTO hr.employee (nom, prenom, email, phone, matricule, date_naissance, poste, departement, type_contrat, date_embauche, date_fin, heures_hebdo)
  VALUES ('Rousseau', 'Emma', 'emma.rousseau@entreprise.fr', '06 56 78 90 12', 'EMP-005', '1990-01-17', 'Conductrice de travaux', 'Production', 'cdd', '2025-11-01', '2026-10-31', 39)
  RETURNING id INTO v_e5;

  INSERT INTO hr.employee (nom, prenom, email, phone, matricule, date_naissance, poste, departement, type_contrat, date_embauche, heures_hebdo, statut, notes)
  VALUES ('Garcia', 'Antoine', 'antoine.garcia@entreprise.fr', '06 67 89 01 23', 'EMP-006', '1985-09-03', 'Menuisier', 'Production', 'cdi', '2018-06-01', 35, 'inactif', 'Parti en retraite anticipée')
  RETURNING id INTO v_e6;

  -- Absences
  INSERT INTO hr.absence (employee_id, type_absence, date_debut, date_fin, nb_jours, motif, statut) VALUES
    (v_e1, 'conge_paye', '2026-04-14', '2026-04-25', 10, 'Vacances Pâques', 'validee'),
    (v_e1, 'formation', '2026-05-05', '2026-05-07', 3, 'Formation sécurité chantier', 'validee'),
    (v_e2, 'maladie', '2026-03-03', '2026-03-07', 5, '', 'validee'),
    (v_e2, 'conge_paye', '2026-07-01', '2026-07-18', 14, 'Congés été', 'demande'),
    (v_e3, 'rtt', '2026-03-14', '2026-03-14', 1, '', 'validee'),
    (v_e3, 'conge_paye', '2026-08-04', '2026-08-22', 15, 'Congés août', 'demande'),
    (v_e4, 'formation', '2026-03-17', '2026-03-21', 5, 'CFA — semaine école', 'validee'),
    (v_e5, 'sans_solde', '2026-06-02', '2026-06-06', 5, 'Convenance personnelle', 'demande');

  -- Timesheet (semaine en cours pour les actifs)
  INSERT INTO hr.timesheet (employee_id, date_travail, heures, description) VALUES
    (v_e1, CURRENT_DATE - 4, 9, 'Chantier Lyon 3e'),
    (v_e1, CURRENT_DATE - 3, 8.5, 'Chantier Lyon 3e'),
    (v_e1, CURRENT_DATE - 2, 9, 'Chantier Villeurbanne'),
    (v_e1, CURRENT_DATE - 1, 8, 'Réunion + administratif'),
    (v_e1, CURRENT_DATE, 7, 'Chantier Villeurbanne (matin)'),
    (v_e2, CURRENT_DATE - 4, 7, 'Pose charpente'),
    (v_e2, CURRENT_DATE - 3, 7, 'Pose charpente'),
    (v_e2, CURRENT_DATE - 2, 7, 'Pose charpente'),
    (v_e2, CURRENT_DATE - 1, 7, 'Finitions'),
    (v_e3, CURRENT_DATE - 4, 7, 'Comptabilité'),
    (v_e3, CURRENT_DATE - 3, 7, 'Paie'),
    (v_e3, CURRENT_DATE - 2, 7, 'Comptabilité'),
    (v_e3, CURRENT_DATE - 1, 7, 'Déclarations'),
    (v_e3, CURRENT_DATE, 7, 'Clôture mensuelle'),
    (v_e5, CURRENT_DATE - 4, 8, 'Suivi chantier Grenoble'),
    (v_e5, CURRENT_DATE - 3, 9, 'Réception matériaux + chantier'),
    (v_e5, CURRENT_DATE - 2, 8.5, 'Chantier Grenoble')
  ON CONFLICT (employee_id, date_travail) DO NOTHING;

  RETURN pgv.toast('6 salariés, 8 absences, 17 pointages créés.');
END;
$function$;
