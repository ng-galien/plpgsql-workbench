CREATE OR REPLACE FUNCTION planning.evenement_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v record;
  v_intervenants jsonb;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('planning.nav_evenements')),
        pgv.ui_table('evenements', jsonb_build_array(
          pgv.ui_col('titre', pgv.t('planning.col_evenement'), pgv.ui_link('{titre}', '/planning/evenements/{id}')),
          pgv.ui_col('type', pgv.t('planning.col_type'), pgv.ui_badge('{type}')),
          pgv.ui_col('date_debut', pgv.t('planning.field_date_debut')),
          pgv.ui_col('date_fin', pgv.t('planning.field_date_fin')),
          pgv.ui_col('lieu', pgv.t('planning.col_lieu')),
          pgv.ui_col('chantier_numero', pgv.t('planning.col_chantier'))
        ))
      ),
      'datasources', jsonb_build_object(
        'evenements', pgv.ui_datasource('planning://evenement', 20, true, '-date_debut')
      )
    );
  END IF;

  -- Detail mode
  SELECT e.*, ch.numero AS chantier_numero INTO v
  FROM planning.evenement e
  LEFT JOIN project.chantier ch ON ch.id = e.chantier_id
  WHERE e.id = p_slug::int AND e.tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('nom', i.nom, 'role', i.role, 'couleur', i.couleur) ORDER BY i.nom), '[]'::jsonb)
  INTO v_intervenants
  FROM planning.affectation a JOIN planning.intervenant i ON i.id = a.intervenant_id
  WHERE a.evenement_id = v.id;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link(E'\u2190 ' || pgv.t('planning.nav_evenements'), '/planning/evenements'),
        pgv.ui_heading(v.titre)
      ),
      pgv.ui_row(
        pgv.ui_badge(v.type),
        pgv.ui_text(to_char(v.date_debut, 'DD/MM/YYYY') || ' -> ' || to_char(v.date_fin, 'DD/MM/YYYY')),
        pgv.ui_text(to_char(v.heure_debut, 'HH24:MI') || ' – ' || to_char(v.heure_fin, 'HH24:MI'))
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('planning.field_lieu') || ': ' || COALESCE(NULLIF(v.lieu, ''), '—')),
        pgv.ui_text(pgv.t('planning.col_chantier') || ': ' || COALESCE(v.chantier_numero, '—'))
      ),
      pgv.ui_text(pgv.t('planning.field_notes') || ': ' || COALESCE(NULLIF(v.notes, ''), '—')),

      pgv.ui_heading(pgv.t('planning.title_equipe_affectee'), 3),
      pgv.ui_text(COALESCE(NULLIF((SELECT string_agg(i->>'nom', ', ' ORDER BY i->>'nom') FROM jsonb_array_elements(v_intervenants) i), ''), '—'))
    )
  );
END;
$function$;
