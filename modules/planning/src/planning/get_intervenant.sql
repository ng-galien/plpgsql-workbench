CREATE OR REPLACE FUNCTION planning.get_intervenant(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v record;
  v_body text;
  v_rows text[];
  r record;
BEGIN
  SELECT * INTO v FROM planning.intervenant WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.error('404', pgv.t('planning.err_intervenant_not_found'));
  END IF;

  v_body := pgv.dl(
    pgv.t('planning.field_nom'), pgv.esc(v.nom),
    pgv.t('planning.field_role'), COALESCE(NULLIF(v.role, ''), '—'),
    pgv.t('planning.field_telephone'), COALESCE(v.telephone, '—'),
    pgv.t('planning.field_couleur'), format('<span class="pgv-color-dot" style="background:%s"></span> %s', v.couleur, v.couleur),
    pgv.t('planning.col_statut'), CASE WHEN v.actif THEN pgv.badge(pgv.t('planning.statut_actif'), 'success') ELSE pgv.badge(pgv.t('planning.statut_inactif'), 'default') END,
    'Ajouté le', to_char(v.created_at, 'DD/MM/YYYY')
  );

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT e.id, e.titre, e.type, e.date_debut, e.date_fin, e.lieu
      FROM planning.evenement e
      JOIN planning.affectation a ON a.evenement_id = e.id
     WHERE a.intervenant_id = p_id AND e.date_fin >= current_date
     ORDER BY e.date_debut
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_evenement', jsonb_build_object('p_id', r.id)), pgv.esc(r.titre)),
      planning._type_badge(r.type),
      to_char(r.date_debut, 'DD/MM') || ' → ' || to_char(r.date_fin, 'DD/MM'),
      COALESCE(NULLIF(r.lieu, ''), '—')
    ];
  END LOOP;

  IF cardinality(v_rows) > 0 THEN
    v_body := v_body || '<h4>' || pgv.t('planning.title_evenements_venir') || '</h4>'
      || pgv.md_table(ARRAY[pgv.t('planning.col_evenement'), pgv.t('planning.col_type'), pgv.t('planning.col_dates'), pgv.t('planning.col_lieu')], v_rows);
  ELSE
    v_body := v_body || pgv.empty(pgv.t('planning.empty_no_evt_venir'));
  END IF;

  v_body := v_body || '<p>'
    || format('<a href="%s" role="button">%s</a> ', pgv.call_ref('get_intervenant_form', jsonb_build_object('p_id', p_id)), pgv.t('planning.btn_modifier'))
    || pgv.action('post_intervenant_supprimer', pgv.t('planning.btn_supprimer'), jsonb_build_object('p_id', p_id), pgv.t('planning.confirm_delete_intervenant'), 'error')
    || '</p>';

  RETURN v_body;
END;
$function$;
