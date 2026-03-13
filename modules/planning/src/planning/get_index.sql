CREATE OR REPLACE FUNCTION planning.get_index(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_date date;
  v_lundi date;
  v_body text;
  v_total_intervenants int;
  v_total_evenements_semaine int;
  v_total_affectations_semaine int;
  v_jour date;
  v_rows text[];
  r record;
  v_evts text;
BEGIN
  v_date := COALESCE((p_params->>'date')::date, current_date);
  v_lundi := v_date - extract(isodow FROM v_date)::int + 1;

  SELECT count(*)::int INTO v_total_intervenants FROM planning.intervenant WHERE actif;
  SELECT count(*)::int INTO v_total_evenements_semaine
    FROM planning.evenement WHERE date_debut <= v_lundi + 6 AND date_fin >= v_lundi;
  SELECT count(*)::int INTO v_total_affectations_semaine
    FROM planning.affectation a
    JOIN planning.evenement e ON e.id = a.evenement_id
   WHERE e.date_debut <= v_lundi + 6 AND e.date_fin >= v_lundi;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('planning.stat_intervenants'), v_total_intervenants::text),
    pgv.stat(pgv.t('planning.stat_evenements_semaine'), v_total_evenements_semaine::text),
    pgv.stat(pgv.t('planning.stat_affectations_semaine'), v_total_affectations_semaine::text)
  ]);

  v_body := v_body || '<nav class="pgv-week-nav">'
    || pgv.link_button(pgv.call_ref('get_index', jsonb_build_object('date', (v_lundi - 7)::text)), '&larr;', 'outline')
    || ' <strong>' || pgv.t('planning.title_semaine_du') || ' ' || to_char(v_lundi, 'DD/MM') || ' au ' || to_char(v_lundi + 6, 'DD/MM/YYYY') || '</strong> '
    || pgv.link_button(pgv.call_ref('get_index', jsonb_build_object('date', (v_lundi + 7)::text)), '&rarr;', 'outline')
    || '</nav>';

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT i.id, i.nom, i.role, i.couleur
      FROM planning.intervenant i
     WHERE i.actif
     ORDER BY i.nom
  LOOP
    v_rows := v_rows || ARRAY[
      format('<strong>%s</strong><br><small>%s</small>', pgv.esc(r.nom), pgv.esc(r.role))
    ];
    FOR d IN 0..6 LOOP
      v_jour := v_lundi + d;
      SELECT string_agg(
        format('<a href="%s" class="pgv-event-chip" style="border-left:3px solid %s">%s</a>',
          pgv.call_ref('get_evenement', jsonb_build_object('p_id', e.id)),
          r.couleur,
          pgv.esc(CASE WHEN length(e.titre) > 15 THEN left(e.titre, 12) || '...' ELSE e.titre END)
        ), '' ORDER BY e.heure_debut
      ) INTO v_evts
        FROM planning.evenement e
        JOIN planning.affectation af ON af.evenement_id = e.id
       WHERE af.intervenant_id = r.id
         AND e.date_debut <= v_jour AND e.date_fin >= v_jour;
      v_rows := v_rows || ARRAY[COALESCE(v_evts, '')];
    END LOOP;
  END LOOP;

  IF v_total_intervenants = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('planning.empty_no_intervenant'), pgv.t('planning.empty_first_intervenant'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[
        pgv.t('planning.col_intervenant'),
        to_char(v_lundi, 'Dy DD'),
        to_char(v_lundi + 1, 'Dy DD'),
        to_char(v_lundi + 2, 'Dy DD'),
        to_char(v_lundi + 3, 'Dy DD'),
        to_char(v_lundi + 4, 'Dy DD'),
        to_char(v_lundi + 5, 'Dy DD'),
        to_char(v_lundi + 6, 'Dy DD')
      ],
      v_rows
    );
  END IF;

  v_body := v_body || '<p>'
    || pgv.form_dialog('dlg-new-evenement', pgv.t('planning.btn_nouvel_evenement'), planning._evenement_form_inputs(), 'post_evenement_save')
    || ' '
    || pgv.link_button(pgv.call_ref('get_intervenants'), pgv.t('planning.btn_gerer_equipe'), 'secondary')
    || '</p>';

  RETURN v_body;
END;
$function$;
