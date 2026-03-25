CREATE OR REPLACE FUNCTION stock.article_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_art stock.article;
  v_supplier text;
  v_stock_total numeric;
BEGIN
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('stock.nav_articles')),
        pgv.ui_table('articles', jsonb_build_array(
          pgv.ui_col('reference', pgv.t('stock.col_ref'), pgv.ui_link('{reference}', '/stock/article/{id}')),
          pgv.ui_col('description', pgv.t('stock.col_designation')),
          pgv.ui_col('category', pgv.t('stock.col_categorie'), pgv.ui_badge('{category}')),
          pgv.ui_col('current_stock', pgv.t('stock.col_stock')),
          pgv.ui_col('unit', pgv.t('stock.col_unite')),
          pgv.ui_col('wap', pgv.t('stock.col_pmp')),
          pgv.ui_col('supplier_name', pgv.t('stock.col_fournisseur')),
          pgv.ui_col('active', pgv.t('stock.col_actif'), pgv.ui_badge('{active}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'articles', pgv.ui_datasource('stock://article', 20, true, 'description')
      )
    );
  END IF;

  SELECT * INTO v_art FROM stock.article WHERE id = p_slug::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'not_found'); END IF;

  SELECT name INTO v_supplier FROM crm.client WHERE id = v_art.supplier_id;
  v_stock_total := stock._current_stock(v_art.id);

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(pgv.ui_link('← ' || pgv.t('stock.nav_articles'), '/stock/articles'), pgv.ui_heading(v_art.description)),
      pgv.ui_row(
        pgv.ui_text(pgv.t('stock.stat_stock_total') || ' : ' || v_stock_total::text || ' ' || v_art.unit),
        pgv.ui_text(pgv.t('stock.stat_pmp') || ' : ' || CASE WHEN v_art.wap > 0 THEN to_char(v_art.wap, 'FM999G990D00') || ' EUR' ELSE '—' END),
        pgv.ui_text(pgv.t('stock.stat_seuil_mini') || ' : ' || CASE WHEN v_art.min_threshold > 0 THEN v_art.min_threshold::text || ' ' || v_art.unit ELSE '—' END)
      ),
      pgv.ui_heading(pgv.t('stock.title_infos'), 3),
      pgv.ui_row(
        pgv.ui_text(pgv.t('stock.label_ref') || ' ' || v_art.reference),
        pgv.ui_badge(v_art.category),
        pgv.ui_badge(CASE WHEN v_art.active THEN pgv.t('stock.yes') ELSE pgv.t('stock.no') END, CASE WHEN v_art.active THEN 'success' ELSE 'error' END)
      ),
      pgv.ui_text(pgv.t('stock.stat_fournisseur') || ' : ' || coalesce(v_supplier, '—'))
    )
  );
END;
$function$;
