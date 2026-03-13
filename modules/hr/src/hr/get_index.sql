CREATE OR REPLACE FUNCTION hr.get_index(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_q text;
  v_statut text;
  v_contrat text;
  v_dept text;
  v_total int;
  v_actifs int;
  v_absences_en_cours int;
  v_rows text[];
  v_body text;
  r record;
BEGIN
  -- Extract filters
  v_q := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_statut := NULLIF(trim(COALESCE(p_params->>'statut', '')), '');
  v_contrat := NULLIF(trim(COALESCE(p_params->>'contrat', '')), '');
  v_dept := NULLIF(trim(COALESCE(p_params->>'dept', '')), '');

  -- Stats
  SELECT count(*)::int INTO v_total FROM hr.employee;
  SELECT count(*)::int INTO v_actifs FROM hr.employee WHERE statut = 'actif';
  SELECT count(*)::int INTO v_absences_en_cours FROM hr.absence
    WHERE statut = 'validee' AND date_debut <= CURRENT_DATE AND date_fin >= CURRENT_DATE;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Total salariés', v_total::text),
    pgv.stat('Actifs', v_actifs::text),
    pgv.stat('En absence', v_absences_en_cours::text)
  ]);

  -- Search/filter form
  v_body := v_body
    || '<form>'
    || '<div class="grid">'
    || pgv.input('q', 'search', 'Recherche nom/poste', v_q)
    || pgv.sel('statut', 'Statut', '[{"label":"Tous","value":""},{"label":"Actif","value":"actif"},{"label":"Inactif","value":"inactif"}]'::jsonb, COALESCE(v_statut, ''))
    || pgv.sel('contrat', 'Contrat', '[{"label":"Tous","value":""},{"label":"CDI","value":"cdi"},{"label":"CDD","value":"cdd"},{"label":"Alternance","value":"alternance"},{"label":"Stage","value":"stage"},{"label":"Intérim","value":"interim"}]'::jsonb, COALESCE(v_contrat, ''))
    || pgv.input('dept', 'text', 'Département', v_dept)
    || '</div>'
    || '<button type="submit" class="secondary">Filtrer</button>'
    || '</form>';

  -- Employee list
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT e.id, e.nom, e.prenom, e.poste, e.departement,
           e.type_contrat, e.date_embauche, e.statut
      FROM hr.employee e
     WHERE (v_q IS NULL OR e.nom ILIKE '%' || v_q || '%' OR e.prenom ILIKE '%' || v_q || '%' OR e.poste ILIKE '%' || v_q || '%')
       AND (v_statut IS NULL OR e.statut = v_statut)
       AND (v_contrat IS NULL OR e.type_contrat = v_contrat)
       AND (v_dept IS NULL OR e.departement ILIKE '%' || v_dept || '%')
     ORDER BY e.nom, e.prenom
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s %s</a>', pgv.call_ref('get_employee', jsonb_build_object('p_id', r.id)), pgv.esc(r.nom), pgv.esc(r.prenom)),
      COALESCE(NULLIF(r.poste, ''), '—'),
      COALESCE(NULLIF(r.departement, ''), '—'),
      hr.contrat_label(r.type_contrat),
      to_char(r.date_embauche, 'DD/MM/YYYY'),
      pgv.badge(upper(r.statut), hr.statut_variant(r.statut))
    ];
  END LOOP;

  IF v_total = 0 THEN
    v_body := v_body || pgv.empty('Aucun salarié', 'Ajoutez votre premier salarié pour commencer.');
  ELSIF cardinality(v_rows) = 0 THEN
    v_body := v_body || pgv.empty('Aucun résultat pour ces filtres.');
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY['Salarié', 'Poste', 'Département', 'Contrat', 'Embauche', 'Statut'],
      v_rows,
      20
    );
  END IF;

  v_body := v_body || pgv.form_dialog('dlg-new-employee',
    'Nouveau salarié',
    hr._employee_form_body(),
    'post_employee_save');

  RETURN v_body;
END;
$function$;
