CREATE OR REPLACE FUNCTION planning.get_intervenants(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_q text;
  v_actif text;
  v_rows text[];
  v_body text;
  r record;
BEGIN
  v_q := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_actif := NULLIF(trim(COALESCE(p_params->>'actif', '')), '');

  v_body := '<form><div class="grid">'
    || pgv.input('q', 'search', pgv.t('planning.filter_recherche_nom'), v_q)
    || pgv.sel('actif', pgv.t('planning.filter_statut'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('planning.filter_tous'), 'value', ''),
         jsonb_build_object('label', pgv.t('planning.filter_actifs'), 'value', 'true'),
         jsonb_build_object('label', pgv.t('planning.filter_inactifs'), 'value', 'false')
       ), COALESCE(v_actif, ''))
    || '</div><button type="submit" class="secondary">' || pgv.t('planning.btn_filtrer') || '</button></form>';

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT i.id, i.nom, i.role, i.telephone, i.couleur, i.actif,
           (SELECT count(*)::int FROM planning.affectation a
              JOIN planning.evenement e ON e.id = a.evenement_id
             WHERE a.intervenant_id = i.id
               AND e.date_fin >= current_date) AS nb_evt_actifs
      FROM planning.intervenant i
     WHERE (v_q IS NULL OR i.nom ILIKE '%' || v_q || '%' OR i.role ILIKE '%' || v_q || '%')
       AND (v_actif IS NULL OR i.actif = (v_actif = 'true'))
     ORDER BY i.actif DESC, i.nom
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_intervenant', jsonb_build_object('p_id', r.id)), pgv.esc(r.nom)),
      COALESCE(r.role, '—'),
      COALESCE(r.telephone, '—'),
      format('<span class="pgv-color-dot" style="background:%s"></span>', r.couleur),
      r.nb_evt_actifs::text,
      CASE WHEN r.actif THEN pgv.badge(pgv.t('planning.statut_actif'), 'success') ELSE pgv.badge(pgv.t('planning.statut_inactif'), 'default') END
    ];
  END LOOP;

  IF cardinality(v_rows) = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('planning.empty_no_intervenant'), pgv.t('planning.empty_equipe'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('planning.col_nom'), pgv.t('planning.col_role'), pgv.t('planning.col_telephone'), pgv.t('planning.col_couleur'), pgv.t('planning.col_evt_actifs'), pgv.t('planning.col_statut')],
      v_rows, 20
    );
  END IF;

  v_body := v_body || '<p>' || pgv.form_dialog('dlg-new-intervenant', pgv.t('planning.btn_nouvel_intervenant'), planning._intervenant_form_inputs(), 'post_intervenant_save') || '</p>';

  RETURN v_body;
END;
$function$;
