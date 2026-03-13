CREATE OR REPLACE FUNCTION planning.get_evenements(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_q text;
  v_type text;
  v_from date;
  v_rows text[];
  v_body text;
  r record;
BEGIN
  v_q := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_type := NULLIF(trim(COALESCE(p_params->>'type', '')), '');
  v_from := COALESCE(NULLIF(trim(COALESCE(p_params->>'from', '')), '')::date, current_date - 30);

  v_body := '<form><div class="grid">'
    || pgv.input('q', 'search', pgv.t('planning.filter_recherche_titre'), v_q)
    || pgv.sel('type', pgv.t('planning.field_type'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('planning.filter_tous'), 'value', ''),
         jsonb_build_object('label', pgv.t('planning.type_chantier'), 'value', 'chantier'),
         jsonb_build_object('label', pgv.t('planning.type_livraison'), 'value', 'livraison'),
         jsonb_build_object('label', pgv.t('planning.type_reunion'), 'value', 'reunion'),
         jsonb_build_object('label', pgv.t('planning.type_conge'), 'value', 'conge'),
         jsonb_build_object('label', pgv.t('planning.type_autre'), 'value', 'autre')
       ), COALESCE(v_type, ''))
    || pgv.input('from', 'date', pgv.t('planning.filter_a_partir_du'), v_from::text)
    || '</div><button type="submit" class="secondary">' || pgv.t('planning.btn_filtrer') || '</button></form>';

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT e.id, e.titre, e.type, e.date_debut, e.date_fin, e.lieu,
           (SELECT string_agg(i.nom, ', ' ORDER BY i.nom)
              FROM planning.affectation a JOIN planning.intervenant i ON i.id = a.intervenant_id
             WHERE a.evenement_id = e.id) AS intervenants,
           ch.numero AS chantier_numero
      FROM planning.evenement e
      LEFT JOIN project.chantier ch ON ch.id = e.chantier_id
     WHERE e.date_fin >= v_from
       AND (v_q IS NULL OR e.titre ILIKE '%' || v_q || '%' OR e.lieu ILIKE '%' || v_q || '%')
       AND (v_type IS NULL OR e.type = v_type)
     ORDER BY e.date_debut DESC
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_evenement', jsonb_build_object('p_id', r.id)), pgv.esc(r.titre)),
      planning._type_badge(r.type),
      to_char(r.date_debut, 'DD/MM') || ' → ' || to_char(r.date_fin, 'DD/MM'),
      COALESCE(NULLIF(r.lieu, ''), '—'),
      COALESCE(r.intervenants, '—'),
      COALESCE(r.chantier_numero, '—')
    ];
  END LOOP;

  IF cardinality(v_rows) = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('planning.empty_no_evenement'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('planning.col_evenement'), pgv.t('planning.col_type'), pgv.t('planning.col_dates'), pgv.t('planning.col_lieu'), pgv.t('planning.col_intervenants'), pgv.t('planning.col_chantier')],
      v_rows, 20
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">%s</a></p>', pgv.call_ref('get_evenement_form'), pgv.t('planning.btn_nouvel_evenement'));

  RETURN v_body;
END;
$function$;
