CREATE OR REPLACE FUNCTION project.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_en_cours int;
  v_preparation int;
  v_clos_mois int;
  v_heures_semaine numeric;
  v_body text;
  v_rows text[];
  v_alert_rows text[];
  r record;
BEGIN
  SELECT count(*)::int INTO v_en_cours
    FROM project.chantier WHERE statut = 'execution';

  SELECT count(*)::int INTO v_preparation
    FROM project.chantier WHERE statut = 'preparation';

  SELECT count(*)::int INTO v_clos_mois
    FROM project.chantier
   WHERE statut = 'clos'
     AND date_fin_reelle >= date_trunc('month', CURRENT_DATE);

  SELECT COALESCE(sum(heures), 0) INTO v_heures_semaine
    FROM project.pointage
   WHERE date_pointage >= date_trunc('week', CURRENT_DATE);

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('project.stat_en_cours'), v_en_cours::text),
    pgv.stat(pgv.t('project.stat_preparation'), v_preparation::text),
    pgv.stat(pgv.t('project.stat_termines_mois'), v_clos_mois::text),
    pgv.stat(pgv.t('project.stat_heures_semaine'), v_heures_semaine::text || ' h')
  ]);

  -- Alertes retard
  v_alert_rows := ARRAY[]::text[];
  FOR r IN
    SELECT c.id, c.numero, cl.name AS client, c.objet,
           project._statut_badge(c.statut) AS statut_badge,
           (CURRENT_DATE - c.date_fin_prevue) AS jours_retard
      FROM project.chantier c
      JOIN crm.client cl ON cl.id = c.client_id
     WHERE c.date_fin_prevue < CURRENT_DATE
       AND c.statut NOT IN ('clos', 'reception')
     ORDER BY c.date_fin_prevue ASC
  LOOP
    v_alert_rows := v_alert_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_chantier', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero)),
      pgv.esc(r.client),
      pgv.esc(r.objet),
      r.statut_badge,
      pgv.badge(r.jours_retard::text || ' j', 'warning')
    ];
  END LOOP;

  IF array_length(v_alert_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>' || pgv.t('project.title_alertes_retard') || '</h3>'
      || pgv.md_table(
        ARRAY[pgv.t('project.col_numero'), pgv.t('project.col_client'), pgv.t('project.col_objet'), pgv.t('project.col_statut'), pgv.t('project.col_retard')],
        v_alert_rows
      );
  END IF;

  -- Liste projets actifs
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT c.id, c.client_id, c.devis_id, c.numero, cl.name AS client, c.objet, c.statut,
           project._avancement_global(c.id) AS pct,
           c.date_debut, d.numero AS devis_numero
      FROM project.chantier c
      JOIN crm.client cl ON cl.id = c.client_id
      LEFT JOIN quote.devis d ON d.id = c.devis_id
     WHERE c.statut IN ('preparation', 'execution', 'reception')
     ORDER BY c.updated_at DESC
     LIMIT 20
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_chantier', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero)),
      format('<a href="/crm/client?p_id=%s">%s</a>', r.client_id, pgv.esc(r.client)),
      pgv.esc(r.objet),
      project._statut_badge(r.statut),
      pgv.badge(r.pct::text || ' %'),
      CASE WHEN r.devis_numero IS NOT NULL
        THEN format('<a href="/quote/devis?p_id=%s">%s</a>', r.devis_id, pgv.esc(r.devis_numero))
        ELSE '—' END,
      COALESCE(to_char(r.date_debut, 'DD/MM/YYYY'), '—')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('project.empty_aucun_actif'), pgv.t('project.empty_premier'));
  ELSE
    v_body := v_body || '<h3>' || pgv.t('project.title_projets_actifs') || '</h3>'
      || pgv.md_table(
        ARRAY[pgv.t('project.col_numero'), pgv.t('project.col_client'), pgv.t('project.col_objet'), pgv.t('project.col_statut'), pgv.t('project.col_avancement'), pgv.t('project.col_devis'), pgv.t('project.col_debut')],
        v_rows, 10
      );
  END IF;

  v_body := v_body || '<p>'
    || pgv.form_dialog('dlg-new-projet', pgv.t('project.btn_nouveau'),
         project._chantier_form_fields(), 'post_chantier_save')
    || '</p>';

  RETURN v_body;
END;
$function$;
