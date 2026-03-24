CREATE OR REPLACE FUNCTION stock.depot_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_dep stock.depot;
  v_nb_articles int;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('stock.nav_depots')),
        pgv.ui_table('depots', jsonb_build_array(
          pgv.ui_col('nom', pgv.t('stock.col_nom'), pgv.ui_link('{nom}', '/stock/depot/{id}')),
          pgv.ui_col('type', pgv.t('stock.col_type'), pgv.ui_badge('{type}')),
          pgv.ui_col('adresse', pgv.t('stock.col_adresse')),
          pgv.ui_col('nb_articles', pgv.t('stock.col_articles')),
          pgv.ui_col('actif', pgv.t('stock.col_actif'), pgv.ui_badge('{actif}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'depots', pgv.ui_datasource('stock://depot', 20, true, 'nom')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_dep FROM stock.depot WHERE id = p_slug::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  SELECT count(DISTINCT m.article_id)::int INTO v_nb_articles
  FROM stock.mouvement m WHERE m.depot_id = v_dep.id;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← ' || pgv.t('stock.nav_depots'), '/stock/depots'),
        pgv.ui_heading(v_dep.nom)
      ),
      pgv.ui_row(
        pgv.ui_badge(v_dep.type),
        pgv.ui_text(pgv.t('stock.col_adresse') || ' : ' || coalesce(v_dep.adresse, '—')),
        pgv.ui_badge(CASE WHEN v_dep.actif THEN pgv.t('stock.yes') ELSE pgv.t('stock.no') END, CASE WHEN v_dep.actif THEN 'success' ELSE 'error' END)
      ),
      pgv.ui_text(pgv.t('stock.col_articles') || ' : ' || v_nb_articles::text)
    )
  );
END;
$function$;
