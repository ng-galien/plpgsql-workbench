CREATE OR REPLACE FUNCTION hr.get_employee(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_emp hr.employee;
  v_fiche text;
  v_absences text;
  v_heures text;
  v_body text;
  v_rows text[];
  r record;
  v_total_heures numeric;
  v_total_absences int;
  v_balance_stats text[];
  v_bal record;
BEGIN
  SELECT * INTO v_emp FROM hr.employee WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.alert('Salarié introuvable.', 'danger');
  END IF;

  -- Fiche
  v_fiche := pgv.dl(VARIADIC ARRAY[
    'Matricule', CASE WHEN v_emp.matricule = '' THEN '—' ELSE pgv.esc(v_emp.matricule) END,
    'Email', COALESCE(v_emp.email, '—'),
    'Téléphone', COALESCE(v_emp.phone, '—'),
    'Date de naissance', CASE WHEN v_emp.date_naissance IS NOT NULL THEN to_char(v_emp.date_naissance, 'DD/MM/YYYY') ELSE '—' END,
    'Sexe', CASE v_emp.sexe WHEN 'M' THEN 'Homme' WHEN 'F' THEN 'Femme' ELSE '—' END,
    'Nationalité', CASE WHEN v_emp.nationalite = '' THEN '—' ELSE pgv.esc(v_emp.nationalite) END,
    'Poste', CASE WHEN v_emp.poste = '' THEN '—' ELSE pgv.esc(v_emp.poste) END,
    'Département', CASE WHEN v_emp.departement = '' THEN '—' ELSE pgv.esc(v_emp.departement) END,
    'Qualification', CASE WHEN v_emp.qualification = '' THEN '—' ELSE pgv.esc(v_emp.qualification) END,
    'Contrat', hr.contrat_label(v_emp.type_contrat),
    'Embauche', to_char(v_emp.date_embauche, 'DD/MM/YYYY'),
    'Fin de contrat', CASE WHEN v_emp.date_fin IS NOT NULL THEN to_char(v_emp.date_fin, 'DD/MM/YYYY') ELSE '—' END,
    'Heures/semaine', v_emp.heures_hebdo::text || 'h',
    'Statut', pgv.badge(upper(v_emp.statut), hr.statut_variant(v_emp.statut)),
    'Notes', CASE WHEN v_emp.notes = '' THEN '—' ELSE pgv.esc(v_emp.notes) END
  ]);

  v_fiche := v_fiche || '<hr>'
    || pgv.form_dialog('dlg-edit-' || p_id,
      'Modifier ' || pgv.esc(v_emp.prenom) || ' ' || pgv.esc(v_emp.nom),
      hr._employee_form_body(v_emp),
      'post_employee_save',
      'Modifier', 'outline') || ' '
    || pgv.action('post_employee_delete', 'Supprimer', jsonb_build_object('id', p_id), 'Supprimer définitivement ce salarié et tout son historique ?', 'danger');

  -- Leave balance stats
  v_balance_stats := ARRAY[]::text[];
  FOR v_bal IN
    SELECT lb.leave_type, lb.allocated, lb.used, (lb.allocated - lb.used) AS remaining
      FROM hr.leave_balance lb
     WHERE lb.employee_id = p_id
     ORDER BY lb.leave_type
  LOOP
    v_balance_stats := v_balance_stats || pgv.stat(
      hr.absence_label(v_bal.leave_type),
      v_bal.remaining::text || 'j / ' || v_bal.allocated::text || 'j',
      CASE WHEN v_bal.remaining <= 0 THEN 'danger' WHEN v_bal.remaining <= 3 THEN 'warning' ELSE NULL END
    );
  END LOOP;

  -- Absences
  v_rows := ARRAY[]::text[];
  SELECT count(*)::int INTO v_total_absences FROM hr.absence WHERE employee_id = p_id;

  FOR r IN
    SELECT a.id, a.type_absence, a.date_debut, a.date_fin, a.nb_jours, a.motif, a.statut
      FROM hr.absence a
     WHERE a.employee_id = p_id
     ORDER BY a.date_debut DESC
  LOOP
    v_rows := v_rows || ARRAY[
      hr.absence_label(r.type_absence),
      to_char(r.date_debut, 'DD/MM/YYYY'),
      to_char(r.date_fin, 'DD/MM/YYYY'),
      r.nb_jours::text || 'j',
      pgv.badge(upper(r.statut), hr.statut_variant(r.statut)),
      CASE WHEN r.statut = 'demande' THEN
        pgv.action('post_absence_validate', 'Valider', jsonb_build_object('id', r.id, 'action', 'valider'))
        || ' ' || pgv.action('post_absence_validate', 'Refuser', jsonb_build_object('id', r.id, 'action', 'refuser'), NULL, 'danger')
      ELSE '—' END
    ];
  END LOOP;

  IF cardinality(v_balance_stats) > 0 THEN
    v_absences := pgv.grid(VARIADIC v_balance_stats);
  ELSE
    v_absences := '';
  END IF;

  IF v_total_absences = 0 THEN
    v_absences := v_absences || pgv.empty('Aucune absence enregistrée');
  ELSE
    v_absences := v_absences || pgv.md_table(
      ARRAY['Type', 'Début', 'Fin', 'Jours', 'Statut', 'Actions'],
      v_rows,
      10
    );
  END IF;

  v_absences := v_absences ||
    pgv.accordion(VARIADIC ARRAY[
      'Déclarer une absence',
      pgv.form('post_absence_save',
        '<input type="hidden" name="employee_id" value="' || p_id || '">'
        || pgv.sel('type_absence', 'Type', '[{"label":"Congé payé","value":"conge_paye"},{"label":"RTT","value":"rtt"},{"label":"Maladie","value":"maladie"},{"label":"Sans solde","value":"sans_solde"},{"label":"Formation","value":"formation"},{"label":"Autre","value":"autre"}]'::jsonb, 'conge_paye')
        || '<div class="grid">'
        || pgv.input('date_debut', 'date', 'Date début', NULL, true)
        || pgv.input('date_fin', 'date', 'Date fin', NULL, true)
        || pgv.input('nb_jours', 'number', 'Nb jours', NULL, true)
        || '</div>'
        || pgv.input('motif', 'text', 'Motif'),
        'Déclarer')
    ]);

  -- Heures (30 derniers jours)
  v_rows := ARRAY[]::text[];
  SELECT COALESCE(sum(t.heures), 0) INTO v_total_heures FROM hr.timesheet t
    WHERE t.employee_id = p_id AND t.date_travail >= CURRENT_DATE - 30;

  FOR r IN
    SELECT t.date_travail, t.heures, t.description
      FROM hr.timesheet t
     WHERE t.employee_id = p_id
     ORDER BY t.date_travail DESC
     LIMIT 30
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.date_travail, 'DD/MM/YYYY'),
      r.heures::text || 'h',
      COALESCE(NULLIF(r.description, ''), '—')
    ];
  END LOOP;

  IF cardinality(v_rows) = 0 THEN
    v_heures := pgv.empty('Aucune heure saisie');
  ELSE
    v_heures := pgv.grid(VARIADIC ARRAY[
      pgv.stat('Heures (30j)', v_total_heures::text || 'h')
    ])
    || pgv.md_table(ARRAY['Date', 'Heures', 'Description'], v_rows, 10);
  END IF;

  v_heures := v_heures ||
    pgv.accordion(VARIADIC ARRAY[
      'Saisir des heures',
      pgv.form('post_timesheet_save',
        '<input type="hidden" name="employee_id" value="' || p_id || '">'
        || '<div class="grid">'
        || pgv.input('date_travail', 'date', 'Date', to_char(CURRENT_DATE, 'YYYY-MM-DD'), true)
        || pgv.input('heures', 'number', 'Heures', NULL, true)
        || '</div>'
        || pgv.input('description', 'text', 'Description'),
        'Enregistrer')
    ]);

  v_body := pgv.breadcrumb(VARIADIC ARRAY['Salariés', pgv.call_ref('get_index'), v_emp.prenom || ' ' || v_emp.nom])
    || pgv.tabs(VARIADIC ARRAY['Fiche', v_fiche, 'Absences (' || v_total_absences || ')', v_absences, 'Heures', v_heures]);

  RETURN v_body;
END;
$function$;
