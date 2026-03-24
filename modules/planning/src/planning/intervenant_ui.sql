CREATE OR REPLACE FUNCTION planning.intervenant_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v record;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('planning.nav_equipe')),
        pgv.ui_table('intervenants', jsonb_build_array(
          pgv.ui_col('nom', pgv.t('planning.col_nom'), pgv.ui_link('{nom}', '/planning/intervenants/{id}')),
          pgv.ui_col('role', pgv.t('planning.col_role')),
          pgv.ui_col('telephone', pgv.t('planning.col_telephone')),
          pgv.ui_col('couleur', pgv.t('planning.col_couleur'), pgv.ui_color('{couleur}')),
          pgv.ui_col('nb_evt_actifs', pgv.t('planning.col_evt_actifs')),
          pgv.ui_col('actif', pgv.t('planning.col_statut'), pgv.ui_badge('{actif}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'intervenants', pgv.ui_datasource('planning://intervenant', 20, true, 'nom')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v FROM planning.intervenant WHERE id = p_slug::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link(E'\u2190 ' || pgv.t('planning.nav_equipe'), '/planning/intervenants'),
        pgv.ui_heading(v.nom)
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('planning.field_role') || ': ' || COALESCE(NULLIF(v.role, ''), '—')),
        pgv.ui_text(pgv.t('planning.field_telephone') || ': ' || COALESCE(v.telephone, '—'))
      ),
      pgv.ui_row(
        pgv.ui_color(v.couleur),
        CASE WHEN v.actif THEN pgv.ui_badge(pgv.t('planning.statut_actif'), 'success') ELSE pgv.ui_badge(pgv.t('planning.statut_inactif')) END
      ),
      pgv.ui_text(pgv.t('planning.field_ajoute_le') || ': ' || to_char(v.created_at, 'DD/MM/YYYY'))
    )
  );
END;
$function$;
