CREATE OR REPLACE FUNCTION catalog.category_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_cat catalog.category;
  v_parent_name text;
  v_article_count int;
BEGIN
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('catalog.nav_categories')),
        pgv.ui_table('categories', jsonb_build_array(
          pgv.ui_col('name', pgv.t('catalog.col_name'), pgv.ui_link('{name}', '/catalog/category/{id}')),
          pgv.ui_col('parent_name', pgv.t('catalog.col_parent')),
          pgv.ui_col('article_count', pgv.t('catalog.col_articles'))
        ))
      ),
      'datasources', jsonb_build_object(
        'categories', pgv.ui_datasource('catalog://category', 20, true, 'name')
      )
    );
  END IF;

  SELECT * INTO v_cat FROM catalog.category WHERE id = p_slug::int;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'not_found'); END IF;

  SELECT p.name INTO v_parent_name FROM catalog.category p WHERE p.id = v_cat.parent_id;
  SELECT count(*)::int INTO v_article_count FROM catalog.article a WHERE a.category_id = v_cat.id;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← ' || pgv.t('catalog.nav_categories'), '/catalog/categories'),
        pgv.ui_heading(v_cat.name)
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('catalog.col_parent') || ': ' || coalesce(v_parent_name, '—')),
        pgv.ui_text(pgv.t('catalog.col_articles') || ': ' || v_article_count)
      ),
      pgv.ui_text(pgv.t('catalog.detail_created_at') || ': ' || to_char(v_cat.created_at, 'DD/MM/YYYY HH24:MI'))
    )
  );
END;
$function$;
