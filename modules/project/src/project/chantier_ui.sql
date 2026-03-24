CREATE OR REPLACE FUNCTION project.chantier_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_row jsonb;
  v_numero text;
  v_objet text;
  v_client text;
  v_statut text;
  v_avancement text;
  v_adresse text;
  v_devis text;
  v_debut text;
  v_fin text;
  v_notes text;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('project.nav_projets')),
        pgv.ui_table('chantiers', jsonb_build_array(
          pgv.ui_col('numero', pgv.t('project.col_numero'), pgv.ui_link('{numero}', '/project/chantier/{id}')),
          pgv.ui_col('client_name', pgv.t('project.col_client')),
          pgv.ui_col('objet', pgv.t('project.col_objet')),
          pgv.ui_col('statut', pgv.t('project.col_statut'), pgv.ui_badge('{statut}')),
          pgv.ui_col('avancement', pgv.t('project.col_avancement')),
          pgv.ui_col('devis_numero', pgv.t('project.col_devis')),
          pgv.ui_col('date_debut', pgv.t('project.col_debut'))
        ))
      ),
      'datasources', jsonb_build_object(
        'chantiers', pgv.ui_datasource('project://chantier', 20, true, 'updated_at')
      )
    );
  END IF;

  -- Detail mode
  v_row := project.chantier_read(p_slug);
  IF v_row IS NULL THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  v_numero := v_row ->> 'numero';
  v_objet := v_row ->> 'objet';
  v_client := v_row ->> 'client_name';
  v_statut := v_row ->> 'statut';
  v_avancement := v_row ->> 'avancement';
  v_adresse := COALESCE(v_row ->> 'adresse', '—');
  v_devis := COALESCE(v_row ->> 'devis_numero', '—');
  v_debut := COALESCE(v_row ->> 'date_debut', '—');
  v_fin := COALESCE(v_row ->> 'date_fin_prevue', '—');
  v_notes := COALESCE(NULLIF(v_row ->> 'notes', ''), '—');

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← ' || pgv.t('project.nav_projets'), '/project/chantiers'),
        pgv.ui_heading(v_numero || ' — ' || v_objet)
      ),
      pgv.ui_heading(pgv.t('project.title_informations'), 3),
      pgv.ui_row(
        pgv.ui_text(pgv.t('project.col_client') || ': ' || v_client),
        pgv.ui_badge(v_statut),
        pgv.ui_text(pgv.t('project.col_avancement') || ': ' || v_avancement || ' %')
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('project.field_adresse') || ': ' || v_adresse),
        pgv.ui_text(pgv.t('project.col_devis') || ': ' || v_devis)
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('project.field_date_debut') || ': ' || v_debut),
        pgv.ui_text(pgv.t('project.field_date_fin_prevue') || ': ' || v_fin)
      ),
      pgv.ui_heading(pgv.t('project.tab_notes'), 3),
      pgv.ui_text(v_notes)
    )
  );
END;
$function$;
