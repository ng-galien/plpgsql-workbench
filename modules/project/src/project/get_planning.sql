CREATE OR REPLACE FUNCTION project.get_planning()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  r record;
  v_tl_items jsonb;
BEGIN
  v_body := '<h3>' || pgv.t('project.title_planning') || '</h3>';

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT c.id, c.numero, cl.name AS client, c.objet,
           project._statut_badge(c.statut) AS statut_badge,
           project._avancement_global(c.id) AS pct,
           c.date_debut, c.date_fin_prevue,
           (SELECT count(*)::int FROM project.affectation a WHERE a.chantier_id = c.id) AS nb_intervenants
      FROM project.chantier c
      JOIN crm.client cl ON cl.id = c.client_id
     WHERE c.statut IN ('preparation', 'execution', 'reception')
     ORDER BY c.date_debut NULLS LAST, c.numero
  LOOP
    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'date', COALESCE(to_char(j.date_prevue, 'DD/MM/YYYY'), '—'),
        'label', j.label,
        'detail', j.pct_avancement || ' %',
        'badge', CASE j.statut WHEN 'valide' THEN 'success' WHEN 'en_cours' THEN 'info' ELSE 'default' END
      ) ORDER BY j.sort_order
    ), '[]'::jsonb)
    INTO v_tl_items
    FROM project.jalon j WHERE j.chantier_id = r.id;

    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_chantier', jsonb_build_object('p_id', r.id)), pgv.esc(r.numero)),
      pgv.esc(r.client),
      r.statut_badge,
      pgv.progress(r.pct, 100),
      COALESCE(to_char(r.date_debut, 'DD/MM'), '—') || ' -> ' || COALESCE(to_char(r.date_fin_prevue, 'DD/MM'), '—'),
      r.nb_intervenants::text,
      CASE WHEN v_tl_items = '[]'::jsonb THEN '—' ELSE pgv.timeline(v_tl_items) END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('project.empty_aucun_actif'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('project.col_projet'), pgv.t('project.col_client'), pgv.t('project.col_statut'), pgv.t('project.col_avancement'), pgv.t('project.col_periode'), pgv.t('project.col_equipe'), pgv.t('project.col_jalons')],
      v_rows
    );
  END IF;

  RETURN v_body;
END;
$function$;
