CREATE OR REPLACE FUNCTION planning.get_evenement(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v record;
  v_body text;
  v_rows text[];
  r record;
  v_chantier_label text;
  v_intervenants_options text;
BEGIN
  SELECT e.*, ch.numero AS chantier_numero
    INTO v
    FROM planning.evenement e
    LEFT JOIN project.chantier ch ON ch.id = e.chantier_id
   WHERE e.id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.error('404', pgv.t('planning.err_evenement_not_found'));
  END IF;

  v_chantier_label := COALESCE(v.chantier_numero, '—');

  v_body := pgv.dl(
    pgv.t('planning.field_titre'), pgv.esc(v.titre),
    pgv.t('planning.field_type'), planning._type_badge(v.type),
    pgv.t('planning.col_dates'), to_char(v.date_debut, 'DD/MM/YYYY') || ' -> ' || to_char(v.date_fin, 'DD/MM/YYYY'),
    pgv.t('planning.field_heure_debut') || ' – ' || pgv.t('planning.field_heure_fin'), to_char(v.heure_debut, 'HH24:MI') || ' – ' || to_char(v.heure_fin, 'HH24:MI'),
    pgv.t('planning.field_lieu'), COALESCE(NULLIF(v.lieu, ''), '—'),
    pgv.t('planning.col_chantier'), v_chantier_label,
    pgv.t('planning.field_notes'), COALESCE(NULLIF(v.notes, ''), '—')
  );

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT i.id, i.nom, i.role, a.id AS affectation_id
      FROM planning.affectation a
      JOIN planning.intervenant i ON i.id = a.intervenant_id
     WHERE a.evenement_id = p_id
     ORDER BY i.nom
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_intervenant', jsonb_build_object('p_id', r.id)), pgv.esc(r.nom)),
      COALESCE(NULLIF(r.role, ''), '—'),
      pgv.action('post_desaffecter', pgv.t('planning.btn_retirer'), jsonb_build_object('p_id', r.affectation_id, 'p_evenement_id', p_id), NULL, 'secondary')
    ];
  END LOOP;

  v_body := v_body || '<h4>' || pgv.t('planning.title_equipe_affectee') || '</h4>';
  IF cardinality(v_rows) > 0 THEN
    v_body := v_body || pgv.md_table(ARRAY[pgv.t('planning.col_intervenant'), pgv.t('planning.col_role'), ''], v_rows);
  ELSE
    v_body := v_body || pgv.empty(pgv.t('planning.empty_no_affectation'));
  END IF;

  SELECT string_agg(
    format('<option value="%s">%s (%s)</option>', i.id, pgv.esc(i.nom), pgv.esc(i.role)),
    '' ORDER BY i.nom
  ) INTO v_intervenants_options
    FROM planning.intervenant i
   WHERE i.actif
     AND i.id NOT IN (SELECT a.intervenant_id FROM planning.affectation a WHERE a.evenement_id = p_id);

  IF v_intervenants_options IS NOT NULL THEN
    v_body := v_body || pgv.form('post_affecter',
      format('<input type="hidden" name="p_evenement_id" value="%s">', p_id)
      || '<div class="grid"><label>' || pgv.t('planning.btn_ajouter_intervenant')
      || '<select name="p_intervenant_id">' || v_intervenants_options || '</select></label></div>'
    , pgv.t('planning.btn_affecter'));
  END IF;

  v_body := v_body || '<p>'
    || pgv.form_dialog('dlg-edit-evenement', pgv.t('planning.btn_modifier'), planning._evenement_form_inputs(v.id, v.titre, v.type, v.date_debut, v.date_fin, v.heure_debut, v.heure_fin, v.lieu, v.chantier_id, v.notes), 'post_evenement_save')
    || ' '
    || pgv.action('post_evenement_supprimer', pgv.t('planning.btn_supprimer'), jsonb_build_object('p_id', p_id), pgv.t('planning.confirm_delete_evenement'), 'error')
    || '</p>';

  RETURN v_body;
END;
$function$;
