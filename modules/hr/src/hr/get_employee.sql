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
  v_total_hours numeric;
  v_total_leaves int;
  v_balance_stats text[];
  v_bal record;
BEGIN
  SELECT * INTO v_emp FROM hr.employee WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.alert('Salarié introuvable.', 'danger');
  END IF;

  -- Fiche
  v_fiche := pgv.dl(VARIADIC ARRAY[
    'Matricule', CASE WHEN v_emp.employee_code = '' THEN '—' ELSE pgv.esc(v_emp.employee_code) END,
    'Email', COALESCE(v_emp.email, '—'),
    'Téléphone', COALESCE(v_emp.phone, '—'),
    'Date de naissance', CASE WHEN v_emp.birth_date IS NOT NULL THEN to_char(v_emp.birth_date, 'DD/MM/YYYY') ELSE '—' END,
    'Sexe', CASE v_emp.gender WHEN 'M' THEN 'Homme' WHEN 'F' THEN 'Femme' ELSE '—' END,
    'Nationalité', CASE WHEN v_emp.nationality = '' THEN '—' ELSE pgv.esc(v_emp.nationality) END,
    'Poste', CASE WHEN v_emp.position = '' THEN '—' ELSE pgv.esc(v_emp.position) END,
    'Département', CASE WHEN v_emp.department = '' THEN '—' ELSE pgv.esc(v_emp.department) END,
    'Qualification', CASE WHEN v_emp.qualification = '' THEN '—' ELSE pgv.esc(v_emp.qualification) END,
    'Contrat', hr.contract_label(v_emp.contract_type),
    'Embauche', to_char(v_emp.hire_date, 'DD/MM/YYYY'),
    'Fin de contrat', CASE WHEN v_emp.end_date IS NOT NULL THEN to_char(v_emp.end_date, 'DD/MM/YYYY') ELSE '—' END,
    'Heures/semaine', v_emp.weekly_hours::text || 'h',
    'Statut', pgv.badge(upper(v_emp.status), hr.status_variant(v_emp.status)),
    'Notes', CASE WHEN v_emp.notes = '' THEN '—' ELSE pgv.esc(v_emp.notes) END
  ]);

  v_fiche := v_fiche || '<hr>'
    || pgv.form_dialog('dlg-edit-' || p_id,
      'Modifier ' || pgv.esc(v_emp.first_name) || ' ' || pgv.esc(v_emp.last_name),
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
      hr.leave_type_label(v_bal.leave_type),
      v_bal.remaining::text || 'j / ' || v_bal.allocated::text || 'j',
      CASE WHEN v_bal.remaining <= 0 THEN 'danger' WHEN v_bal.remaining <= 3 THEN 'warning' ELSE NULL END
    );
  END LOOP;

  -- Absences
  v_rows := ARRAY[]::text[];
  SELECT count(*)::int INTO v_total_leaves FROM hr.leave_request WHERE employee_id = p_id;

  FOR r IN
    SELECT a.id, a.leave_type, a.start_date, a.end_date, a.day_count, a.reason, a.status
      FROM hr.leave_request a
     WHERE a.employee_id = p_id
     ORDER BY a.start_date DESC
  LOOP
    v_rows := v_rows || ARRAY[
      hr.leave_type_label(r.leave_type),
      to_char(r.start_date, 'DD/MM/YYYY'),
      to_char(r.end_date, 'DD/MM/YYYY'),
      r.day_count::text || 'j',
      pgv.badge(upper(r.status), hr.status_variant(r.status)),
      CASE WHEN r.status = 'pending' THEN
        pgv.action('post_absence_validate', 'Valider', jsonb_build_object('id', r.id, 'action', 'validate'))
        || ' ' || pgv.action('post_absence_validate', 'Refuser', jsonb_build_object('id', r.id, 'action', 'refuse'), NULL, 'danger')
      ELSE '—' END
    ];
  END LOOP;

  IF cardinality(v_balance_stats) > 0 THEN
    v_absences := pgv.grid(VARIADIC v_balance_stats);
  ELSE
    v_absences := '';
  END IF;

  IF v_total_leaves = 0 THEN
    v_absences := v_absences || pgv.empty('Aucune absence enregistrée');
  ELSE
    v_absences := v_absences || pgv.md_table(
      ARRAY['Type', 'Début', 'Fin', 'Jours', 'Statut', 'Actions'],
      v_rows, 10
    );
  END IF;

  v_absences := v_absences ||
    pgv.accordion(VARIADIC ARRAY[
      'Déclarer une absence',
      pgv.form('post_absence_save',
        '<input type="hidden" name="employee_id" value="' || p_id || '">'
        || pgv.sel('leave_type', 'Type', '[{"label":"Congé payé","value":"paid_leave"},{"label":"RTT","value":"rtt"},{"label":"Maladie","value":"sick"},{"label":"Sans solde","value":"unpaid"},{"label":"Formation","value":"training"},{"label":"Autre","value":"other"}]'::jsonb, 'paid_leave')
        || '<div class="grid">'
        || pgv.input('start_date', 'date', 'Date début', NULL, true)
        || pgv.input('end_date', 'date', 'Date fin', NULL, true)
        || pgv.input('day_count', 'number', 'Nb jours', NULL, true)
        || '</div>'
        || pgv.input('reason', 'text', 'Motif'),
        'Déclarer')
    ]);

  -- Hours (30 days)
  v_rows := ARRAY[]::text[];
  SELECT COALESCE(sum(t.hours), 0) INTO v_total_hours FROM hr.timesheet t
    WHERE t.employee_id = p_id AND t.work_date >= CURRENT_DATE - 30;

  FOR r IN
    SELECT t.work_date, t.hours, t.description
      FROM hr.timesheet t
     WHERE t.employee_id = p_id
     ORDER BY t.work_date DESC
     LIMIT 30
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.work_date, 'DD/MM/YYYY'),
      r.hours::text || 'h',
      COALESCE(NULLIF(r.description, ''), '—')
    ];
  END LOOP;

  IF cardinality(v_rows) = 0 THEN
    v_heures := pgv.empty('Aucune heure saisie');
  ELSE
    v_heures := pgv.grid(VARIADIC ARRAY[
      pgv.stat('Heures (30j)', v_total_hours::text || 'h')
    ])
    || pgv.md_table(ARRAY['Date', 'Heures', 'Description'], v_rows, 10);
  END IF;

  v_heures := v_heures ||
    pgv.accordion(VARIADIC ARRAY[
      'Saisir des heures',
      pgv.form('post_timesheet_save',
        '<input type="hidden" name="employee_id" value="' || p_id || '">'
        || '<div class="grid">'
        || pgv.input('work_date', 'date', 'Date', to_char(CURRENT_DATE, 'YYYY-MM-DD'), true)
        || pgv.input('hours', 'number', 'Heures', NULL, true)
        || '</div>'
        || pgv.input('description', 'text', 'Description'),
        'Enregistrer')
    ]);

  v_body := pgv.breadcrumb(VARIADIC ARRAY['Salariés', pgv.call_ref('get_index'), v_emp.first_name || ' ' || v_emp.last_name])
    || pgv.tabs(VARIADIC ARRAY['Fiche', v_fiche, 'Absences (' || v_total_leaves || ')', v_absences, 'Heures', v_heures]);

  RETURN v_body;
END;
$function$;
