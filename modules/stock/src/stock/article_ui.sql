CREATE OR REPLACE FUNCTION stock.article_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_art stock.article;
  v_fournisseur text;
  v_stock_total numeric;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('stock.nav_articles')),
        pgv.ui_table('articles', jsonb_build_array(
          pgv.ui_col('reference', pgv.t('stock.col_ref'), pgv.ui_link('{reference}', '/stock/article/{id}')),
          pgv.ui_col('designation', pgv.t('stock.col_designation')),
          pgv.ui_col('categorie', pgv.t('stock.col_categorie'), pgv.ui_badge('{categorie}')),
          pgv.ui_col('stock_actuel', pgv.t('stock.col_stock')),
          pgv.ui_col('unite', pgv.t('stock.col_unite')),
          pgv.ui_col('pmp', pgv.t('stock.col_pmp')),
          pgv.ui_col('fournisseur_name', pgv.t('stock.col_fournisseur')),
          pgv.ui_col('active', pgv.t('stock.col_actif'), pgv.ui_badge('{active}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'articles', pgv.ui_datasource('stock://article', 20, true, 'designation')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_art FROM stock.article WHERE id = p_slug::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  SELECT name INTO v_fournisseur FROM crm.client WHERE id = v_art.fournisseur_id;
  v_stock_total := stock._stock_actuel(v_art.id);

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← ' || pgv.t('stock.nav_articles'), '/stock/articles'),
        pgv.ui_heading(v_art.designation)
      ),
      -- Stats
      pgv.ui_row(
        pgv.ui_text(pgv.t('stock.stat_stock_total') || ' : ' || v_stock_total::text || ' ' || v_art.unite),
        pgv.ui_text(pgv.t('stock.stat_pmp') || ' : ' || CASE WHEN v_art.pmp > 0 THEN to_char(v_art.pmp, 'FM999G990D00') || ' EUR' ELSE '—' END),
        pgv.ui_text(pgv.t('stock.stat_seuil_mini') || ' : ' || CASE WHEN v_art.seuil_mini > 0 THEN v_art.seuil_mini::text || ' ' || v_art.unite ELSE '—' END)
      ),
      -- Info
      pgv.ui_heading(pgv.t('stock.title_infos'), 3),
      pgv.ui_row(
        pgv.ui_text(pgv.t('stock.label_ref') || ' ' || v_art.reference),
        pgv.ui_badge(v_art.categorie),
        pgv.ui_badge(CASE WHEN v_art.active THEN pgv.t('stock.yes') ELSE pgv.t('stock.no') END, CASE WHEN v_art.active THEN 'success' ELSE 'error' END)
      ),
      -- Fournisseur
      pgv.ui_text(pgv.t('stock.stat_fournisseur') || ' : ' || coalesce(v_fournisseur, '—'))
    )
  );
END;
$function$;
