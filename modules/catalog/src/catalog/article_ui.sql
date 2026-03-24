CREATE OR REPLACE FUNCTION catalog.article_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_art catalog.article;
  v_categorie_nom text;
  v_unite_label text;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('catalog.nav_articles')),
        pgv.ui_table('articles', jsonb_build_array(
          pgv.ui_col('reference', pgv.t('catalog.col_ref'), pgv.ui_link('{reference}', '/catalog/article/{id}')),
          pgv.ui_col('designation', pgv.t('catalog.col_designation')),
          pgv.ui_col('categorie_nom', pgv.t('catalog.col_categorie'), pgv.ui_badge('{categorie_nom}')),
          pgv.ui_col('prix_vente', pgv.t('catalog.col_pv_ht')),
          pgv.ui_col('prix_achat', pgv.t('catalog.col_pa_ht')),
          pgv.ui_col('unite_label', pgv.t('catalog.col_unite')),
          pgv.ui_col('tva', pgv.t('catalog.col_tva')),
          pgv.ui_col('actif', pgv.t('catalog.col_statut'), pgv.ui_badge('{actif}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'articles', pgv.ui_datasource('catalog://article', 20, true, 'designation')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_art FROM catalog.article WHERE id = p_slug::int;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  SELECT c.nom INTO v_categorie_nom FROM catalog.categorie c WHERE c.id = v_art.categorie_id;
  SELECT u.label INTO v_unite_label FROM catalog.unite u WHERE u.code = v_art.unite;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← ' || pgv.t('catalog.nav_articles'), '/catalog/articles'),
        pgv.ui_heading(v_art.designation)
      ),

      -- Prix & unité
      pgv.ui_row(
        pgv.ui_text(pgv.t('catalog.field_prix_vente') || ': ' || CASE WHEN v_art.prix_vente IS NOT NULL THEN to_char(v_art.prix_vente, 'FM999G990D00') || ' EUR' ELSE '—' END),
        pgv.ui_text(pgv.t('catalog.field_prix_achat') || ': ' || CASE WHEN v_art.prix_achat IS NOT NULL THEN to_char(v_art.prix_achat, 'FM999G990D00') || ' EUR' ELSE '—' END),
        pgv.ui_text(pgv.t('catalog.field_tva') || ': ' || v_art.tva || '%'),
        pgv.ui_text(pgv.t('catalog.field_unite') || ': ' || coalesce(v_unite_label, v_art.unite))
      ),

      -- Détails
      pgv.ui_heading(pgv.t('catalog.field_reference'), 3),
      pgv.ui_text(coalesce(v_art.reference, '—')),

      pgv.ui_heading(pgv.t('catalog.field_categorie'), 3),
      pgv.ui_text(coalesce(v_categorie_nom, '—')),

      pgv.ui_heading(pgv.t('catalog.field_description'), 3),
      pgv.ui_text(coalesce(v_art.description, '—')),

      pgv.ui_row(
        pgv.ui_badge(CASE WHEN v_art.actif THEN pgv.t('catalog.badge_actif') ELSE pgv.t('catalog.badge_inactif') END,
                     CASE WHEN v_art.actif THEN 'success' ELSE 'warning' END),
        pgv.ui_text(pgv.t('catalog.detail_created_at') || ': ' || to_char(v_art.created_at, 'DD/MM/YYYY HH24:MI')),
        pgv.ui_text(pgv.t('catalog.detail_updated_at') || ': ' || to_char(v_art.updated_at, 'DD/MM/YYYY HH24:MI'))
      )
    )
  );
END;
$function$;
