CREATE OR REPLACE FUNCTION catalog.article_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_art catalog.article;
  v_category_name text;
  v_unit_label text;
BEGIN
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('catalog.nav_articles')),
        pgv.ui_table('articles', jsonb_build_array(
          pgv.ui_col('reference', pgv.t('catalog.col_ref'), pgv.ui_link('{reference}', '/catalog/article/{id}')),
          pgv.ui_col('name', pgv.t('catalog.col_name')),
          pgv.ui_col('category_name', pgv.t('catalog.col_category'), pgv.ui_badge('{category_name}')),
          pgv.ui_col('sale_price', pgv.t('catalog.col_sale_price')),
          pgv.ui_col('purchase_price', pgv.t('catalog.col_purchase_price')),
          pgv.ui_col('unit_label', pgv.t('catalog.col_unit')),
          pgv.ui_col('vat_rate', pgv.t('catalog.col_vat_rate')),
          pgv.ui_col('active', pgv.t('catalog.col_status'), pgv.ui_badge('{active}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'articles', pgv.ui_datasource('catalog://article', 20, true, 'name')
      )
    );
  END IF;

  SELECT * INTO v_art FROM catalog.article WHERE id = p_slug::int;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'not_found'); END IF;

  SELECT c.name INTO v_category_name FROM catalog.category c WHERE c.id = v_art.category_id;
  SELECT u.label INTO v_unit_label FROM catalog.unit u WHERE u.code = v_art.unit;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← ' || pgv.t('catalog.nav_articles'), '/catalog/articles'),
        pgv.ui_heading(v_art.name)
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('catalog.field_sale_price') || ': ' || CASE WHEN v_art.sale_price IS NOT NULL THEN to_char(v_art.sale_price, 'FM999G990D00') || ' EUR' ELSE '—' END),
        pgv.ui_text(pgv.t('catalog.field_purchase_price') || ': ' || CASE WHEN v_art.purchase_price IS NOT NULL THEN to_char(v_art.purchase_price, 'FM999G990D00') || ' EUR' ELSE '—' END),
        pgv.ui_text(pgv.t('catalog.field_vat_rate') || ': ' || v_art.vat_rate || '%'),
        pgv.ui_text(pgv.t('catalog.field_unit') || ': ' || coalesce(v_unit_label, v_art.unit))
      ),
      pgv.ui_heading(pgv.t('catalog.field_reference'), 3),
      pgv.ui_text(coalesce(v_art.reference, '—')),
      pgv.ui_heading(pgv.t('catalog.field_category'), 3),
      pgv.ui_text(coalesce(v_category_name, '—')),
      pgv.ui_heading(pgv.t('catalog.field_description'), 3),
      pgv.ui_text(coalesce(v_art.description, '—')),
      pgv.ui_row(
        pgv.ui_badge(CASE WHEN v_art.active THEN pgv.t('catalog.badge_active') ELSE pgv.t('catalog.badge_inactive') END,
                     CASE WHEN v_art.active THEN 'success' ELSE 'warning' END),
        pgv.ui_text(pgv.t('catalog.detail_created_at') || ': ' || to_char(v_art.created_at, 'DD/MM/YYYY HH24:MI')),
        pgv.ui_text(pgv.t('catalog.detail_updated_at') || ': ' || to_char(v_art.updated_at, 'DD/MM/YYYY HH24:MI'))
      )
    )
  );
END;
$function$;
