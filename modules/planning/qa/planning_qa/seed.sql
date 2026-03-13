CREATE OR REPLACE FUNCTION planning_qa.seed()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_i1 int; v_i2 int; v_i3 int; v_i4 int; v_i5 int;
  v_e1 int; v_e2 int; v_e3 int; v_e4 int; v_e5 int; v_e6 int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- Clean existing QA data
  DELETE FROM planning.affectation WHERE tenant_id = 'dev';
  DELETE FROM planning.evenement WHERE tenant_id = 'dev';
  DELETE FROM planning.intervenant WHERE tenant_id = 'dev';

  -- 5 intervenants réalistes
  INSERT INTO planning.intervenant (nom, role, telephone, couleur)
  VALUES ('Dupont Marie', 'Chef de chantier', '06 12 34 56 78', '#3b82f6')
  RETURNING id INTO v_i1;

  INSERT INTO planning.intervenant (nom, role, telephone, couleur)
  VALUES ('Martin Thomas', 'Charpentier', '06 23 45 67 89', '#10b981')
  RETURNING id INTO v_i2;

  INSERT INTO planning.intervenant (nom, role, telephone, couleur)
  VALUES ('Lefebvre Paul', 'Électricien', '06 34 56 78 90', '#f59e0b')
  RETURNING id INTO v_i3;

  INSERT INTO planning.intervenant (nom, role, telephone, couleur)
  VALUES ('Moreau Lucas', 'Apprenti couvreur', '06 45 67 89 01', '#8b5cf6')
  RETURNING id INTO v_i4;

  INSERT INTO planning.intervenant (nom, role, telephone, couleur, actif)
  VALUES ('Garcia Antoine', 'Menuisier', '06 56 78 90 12', '#ef4444', false)
  RETURNING id INTO v_i5;

  -- 6 événements (semaine en cours + semaine prochaine)
  INSERT INTO planning.evenement (titre, type, date_debut, date_fin, heure_debut, heure_fin, lieu, notes)
  VALUES ('Charpente maison Durand', 'chantier', current_date, current_date + 4, '07:30', '16:30', '12 rue des Lilas, Lyon 3e', 'Pose charpente traditionnelle')
  RETURNING id INTO v_e1;

  INSERT INTO planning.evenement (titre, type, date_debut, date_fin, heure_debut, heure_fin, lieu)
  VALUES ('Rénovation toiture Mercier', 'chantier', current_date + 2, current_date + 8, '08:00', '17:00', '5 impasse du Clos, Villeurbanne')
  RETURNING id INTO v_e2;

  INSERT INTO planning.evenement (titre, type, date_debut, date_fin, heure_debut, heure_fin, lieu, notes)
  VALUES ('Livraison bois chantier Durand', 'livraison', current_date + 1, current_date + 1, '08:00', '10:00', '12 rue des Lilas, Lyon 3e', 'Camion grue nécessaire')
  RETURNING id INTO v_e3;

  INSERT INTO planning.evenement (titre, type, date_debut, date_fin, heure_debut, heure_fin, lieu)
  VALUES ('Réunion hebdo équipe', 'reunion', current_date - extract(isodow FROM current_date)::int + 1, current_date - extract(isodow FROM current_date)::int + 1, '08:00', '09:00', 'Bureau — salle de réunion')
  RETURNING id INTO v_e4;

  INSERT INTO planning.evenement (titre, type, date_debut, date_fin, notes)
  VALUES ('Congé Moreau', 'conge', current_date + 7, current_date + 11, 'Congés payés')
  RETURNING id INTO v_e5;

  INSERT INTO planning.evenement (titre, type, date_debut, date_fin, heure_debut, heure_fin, lieu)
  VALUES ('Câblage cuisine Petit', 'chantier', current_date + 3, current_date + 5, '08:00', '16:00', '8 avenue Berthelot, Lyon 7e')
  RETURNING id INTO v_e6;

  -- Affectations
  INSERT INTO planning.affectation (evenement_id, intervenant_id) VALUES
    (v_e1, v_i1),  -- Dupont sur charpente Durand
    (v_e1, v_i2),  -- Martin sur charpente Durand
    (v_e1, v_i4),  -- Moreau (apprenti) sur charpente Durand
    (v_e2, v_i1),  -- Dupont sur rénovation Mercier
    (v_e2, v_i2),  -- Martin sur rénovation Mercier
    (v_e3, v_i2),  -- Martin réceptionne la livraison
    (v_e4, v_i1),  -- Dupont à la réunion
    (v_e4, v_i3),  -- Lefebvre à la réunion
    (v_e5, v_i4),  -- Moreau en congé
    (v_e6, v_i3);  -- Lefebvre sur câblage

  RETURN '<template data-toast="success">5 intervenants, 6 événements, 10 affectations créés.</template>';
END;
$function$;
