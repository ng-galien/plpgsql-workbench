CREATE OR REPLACE FUNCTION catalog.categorie_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_cat catalog.categorie;
  v_parent_nom text;
  v_nb_articles int;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('catalog.nav_categories')),
        pgv.ui_table('categories', jsonb_build_array(
          pgv.ui_col('nom', pgv.t('catalog.col_nom'), pgv.ui_link('{nom}', '/catalog/categorie/{id}')),
          pgv.ui_col('parent_nom', pgv.t('catalog.col_parente')),
          pgv.ui_col('nb_articles', pgv.t('catalog.col_articles'))
        ))
      ),
      'datasources', jsonb_build_object(
        'categories', pgv.ui_datasource('catalog://categorie', 20, true, 'nom')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_cat FROM catalog.categorie WHERE id = p_slug::int;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  SELECT p.nom INTO v_parent_nom FROM catalog.categorie p WHERE p.id = v_cat.parent_id;
  SELECT count(*)::int INTO v_nb_articles FROM catalog.article a WHERE a.categorie_id = v_cat.id;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← ' || pgv.t('catalog.nav_categories'), '/catalog/categories'),
        pgv.ui_heading(v_cat.nom)
      ),

      pgv.ui_row(
        pgv.ui_text(pgv.t('catalog.col_parente') || ': ' || coalesce(v_parent_nom, '—')),
        pgv.ui_text(pgv.t('catalog.col_articles') || ': ' || v_nb_articles)
      ),

      pgv.ui_text(pgv.t('catalog.detail_created_at') || ': ' || to_char(v_cat.created_at, 'DD/MM/YYYY HH24:MI'))
    )
  );
END;
$function$;
