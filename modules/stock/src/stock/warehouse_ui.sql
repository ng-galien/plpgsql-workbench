CREATE OR REPLACE FUNCTION stock.warehouse_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_wh stock.warehouse;
  v_nb_articles int;
BEGIN
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('stock.nav_depots')),
        pgv.ui_table('warehouses', jsonb_build_array(
          pgv.ui_col('name', pgv.t('stock.col_nom'), pgv.ui_link('{name}', '/stock/warehouse/{id}')),
          pgv.ui_col('type', pgv.t('stock.col_type'), pgv.ui_badge('{type}')),
          pgv.ui_col('address', pgv.t('stock.col_adresse')),
          pgv.ui_col('article_count', pgv.t('stock.col_articles')),
          pgv.ui_col('active', pgv.t('stock.col_actif'), pgv.ui_badge('{active}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'warehouses', pgv.ui_datasource('stock://warehouse', 20, true, 'name')
      )
    );
  END IF;

  SELECT * INTO v_wh FROM stock.warehouse WHERE id = p_slug::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'not_found'); END IF;

  SELECT count(DISTINCT m.article_id)::int INTO v_nb_articles
  FROM stock.movement m WHERE m.warehouse_id = v_wh.id;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(pgv.ui_link('← ' || pgv.t('stock.nav_depots'), '/stock/warehouses'), pgv.ui_heading(v_wh.name)),
      pgv.ui_row(
        pgv.ui_badge(v_wh.type),
        pgv.ui_text(pgv.t('stock.col_adresse') || ' : ' || coalesce(v_wh.address, '—')),
        pgv.ui_badge(CASE WHEN v_wh.active THEN pgv.t('stock.yes') ELSE pgv.t('stock.no') END, CASE WHEN v_wh.active THEN 'success' ELSE 'error' END)
      ),
      pgv.ui_text(pgv.t('stock.col_articles') || ' : ' || v_nb_articles::text)
    )
  );
END;
$function$;
