CREATE OR REPLACE FUNCTION hr.get_absences(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_statut text;
  v_type text;
  v_mois text;
  v_rows text[];
  v_body text;
  v_en_cours int;
  v_demandes int;
  v_total_mois int;
  r record;
BEGIN
  v_statut := NULLIF(trim(COALESCE(p_params->>'statut', '')), '');
  v_type := NULLIF(trim(COALESCE(p_params->>'type', '')), '');
  v_mois := NULLIF(trim(COALESCE(p_params->>'mois', '')), '');

  -- Stats
  SELECT count(*)::int INTO v_en_cours FROM hr.absence
    WHERE statut = 'validee' AND date_debut <= CURRENT_DATE AND date_fin >= CURRENT_DATE;
  SELECT count(*)::int INTO v_demandes FROM hr.absence WHERE statut = 'demande';
  SELECT count(*)::int INTO v_total_mois FROM hr.absence
    WHERE date_debut >= date_trunc('month', CURRENT_DATE) AND date_debut < date_trunc('month', CURRENT_DATE) + interval '1 month';

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('En cours', v_en_cours::text),
    pgv.stat('En attente', v_demandes::text),
    pgv.stat('Ce mois', v_total_mois::text)
  ]);

  -- Filters
  v_body := v_body || '<form><div class="grid">'
    || pgv.sel('statut', 'Statut', '[{"label":"Tous","value":""},{"label":"Demande","value":"demande"},{"label":"Validée","value":"validee"},{"label":"Refusée","value":"refusee"},{"label":"Annulée","value":"annulee"}]'::jsonb, COALESCE(v_statut, ''))
    || pgv.sel('type', 'Type', '[{"label":"Tous","value":""},{"label":"Congé payé","value":"conge_paye"},{"label":"RTT","value":"rtt"},{"label":"Maladie","value":"maladie"},{"label":"Sans solde","value":"sans_solde"},{"label":"Formation","value":"formation"},{"label":"Autre","value":"autre"}]'::jsonb, COALESCE(v_type, ''))
    || pgv.input('mois', 'month', 'Mois', v_mois)
    || '</div><button type="submit" class="secondary">Filtrer</button></form>';

  -- List
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, e.nom, e.prenom, e.id AS eid, a.type_absence, a.date_debut, a.date_fin, a.nb_jours, a.statut
      FROM hr.absence a
      JOIN hr.employee e ON e.id = a.employee_id
     WHERE (v_statut IS NULL OR a.statut = v_statut)
       AND (v_type IS NULL OR a.type_absence = v_type)
       AND (v_mois IS NULL OR to_char(a.date_debut, 'YYYY-MM') = v_mois)
     ORDER BY a.date_debut DESC
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s %s</a>', pgv.call_ref('get_employee', jsonb_build_object('p_id', r.eid)), pgv.esc(r.nom), pgv.esc(r.prenom)),
      hr.absence_label(r.type_absence),
      to_char(r.date_debut, 'DD/MM/YYYY'),
      to_char(r.date_fin, 'DD/MM/YYYY'),
      r.nb_jours::text || 'j',
      pgv.badge(upper(r.statut), hr.statut_variant(r.statut))
    ];
  END LOOP;

  IF cardinality(v_rows) = 0 THEN
    v_body := v_body || pgv.empty('Aucune absence trouvée.');
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY['Salarié', 'Type', 'Début', 'Fin', 'Jours', 'Statut'],
      v_rows,
      20
    );
  END IF;

  RETURN v_body;
END;
$function$;
