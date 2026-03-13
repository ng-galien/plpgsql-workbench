CREATE OR REPLACE FUNCTION hr.get_timesheet(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_semaine text;
  v_dept text;
  v_rows text[];
  v_body text;
  v_total_semaine numeric;
  v_nb_salaries int;
  v_date_debut date;
  v_date_fin date;
  r record;
BEGIN
  v_semaine := NULLIF(trim(COALESCE(p_params->>'semaine', '')), '');
  v_dept := NULLIF(trim(COALESCE(p_params->>'dept', '')), '');

  -- Default to current week
  IF v_semaine IS NOT NULL THEN
    v_date_debut := v_semaine::date;
  ELSE
    v_date_debut := date_trunc('week', CURRENT_DATE)::date;
  END IF;
  v_date_fin := v_date_debut + 6;

  -- Stats
  SELECT COALESCE(sum(t.heures), 0), count(DISTINCT t.employee_id)::int
    INTO v_total_semaine, v_nb_salaries
    FROM hr.timesheet t
    JOIN hr.employee e ON e.id = t.employee_id
   WHERE t.date_travail BETWEEN v_date_debut AND v_date_fin
     AND (v_dept IS NULL OR e.departement ILIKE '%' || v_dept || '%');

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat('Semaine du', to_char(v_date_debut, 'DD/MM/YYYY')),
    pgv.stat('Total heures', v_total_semaine::text || 'h'),
    pgv.stat('Salariés', v_nb_salaries::text)
  ]);

  -- Filters
  v_body := v_body || '<form><div class="grid">'
    || pgv.input('semaine', 'date', 'Début de semaine', to_char(v_date_debut, 'YYYY-MM-DD'))
    || pgv.input('dept', 'text', 'Département', v_dept)
    || '</div><button type="submit" class="secondary">Filtrer</button></form>';

  -- Per-employee summary for the week
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT e.id, e.nom, e.prenom, e.departement, e.heures_hebdo,
           COALESCE(sum(t.heures), 0) AS total
      FROM hr.employee e
      LEFT JOIN hr.timesheet t ON t.employee_id = e.id
           AND t.date_travail BETWEEN v_date_debut AND v_date_fin
     WHERE e.statut = 'actif'
       AND (v_dept IS NULL OR e.departement ILIKE '%' || v_dept || '%')
     GROUP BY e.id, e.nom, e.prenom, e.departement, e.heures_hebdo
     ORDER BY e.nom, e.prenom
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s %s</a>', pgv.call_ref('get_employee', jsonb_build_object('p_id', r.id)), pgv.esc(r.nom), pgv.esc(r.prenom)),
      COALESCE(NULLIF(r.departement, ''), '—'),
      r.total::text || 'h',
      r.heures_hebdo::text || 'h',
      CASE WHEN r.total >= r.heures_hebdo THEN pgv.badge('OK', 'success')
           WHEN r.total > 0 THEN pgv.badge('Partiel', 'warning')
           ELSE pgv.badge('Vide', 'default') END
    ];
  END LOOP;

  IF cardinality(v_rows) = 0 THEN
    v_body := v_body || pgv.empty('Aucun salarié actif.');
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY['Salarié', 'Département', 'Heures', 'Objectif', 'Statut'],
      v_rows,
      20
    );
  END IF;

  RETURN v_body;
END;
$function$;
