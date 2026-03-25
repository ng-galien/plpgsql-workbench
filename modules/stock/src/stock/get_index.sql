CREATE OR REPLACE FUNCTION stock.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_nb_articles int;
  v_nb_alerts int;
  v_mvt_week int;
  v_mvt_week_prev int;
  v_total_value numeric;
  v_body text;
  v_rows text[];
  v_variation text;
  r record;
BEGIN
  SELECT count(*)::int INTO v_nb_articles FROM stock.article WHERE active;

  SELECT count(*)::int INTO v_nb_alerts
  FROM stock.article a
  WHERE a.active AND a.min_threshold > 0
    AND stock._current_stock(a.id) < a.min_threshold;

  SELECT count(*)::int INTO v_mvt_week
  FROM stock.movement
  WHERE created_at >= date_trunc('week', now());

  SELECT count(*)::int INTO v_mvt_week_prev
  FROM stock.movement
  WHERE created_at >= date_trunc('week', now()) - interval '7 days'
    AND created_at < date_trunc('week', now());

  IF v_mvt_week_prev > 0 THEN
    v_variation := CASE
      WHEN v_mvt_week > v_mvt_week_prev THEN '+' || round(((v_mvt_week - v_mvt_week_prev)::numeric / v_mvt_week_prev) * 100)::text || '%'
      WHEN v_mvt_week < v_mvt_week_prev THEN '-' || round(((v_mvt_week_prev - v_mvt_week)::numeric / v_mvt_week_prev) * 100)::text || '%'
      ELSE '='
    END;
  ELSE
    v_variation := NULL;
  END IF;

  SELECT coalesce(sum(stock._current_stock(a.id) * a.wap), 0)
  INTO v_total_value
  FROM stock.article a
  WHERE a.active AND a.wap > 0;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('stock.stat_articles'), v_nb_articles::text),
    pgv.stat(pgv.t('stock.stat_valeur_stock'), to_char(v_total_value, 'FM999G999G990D00') || ' EUR'),
    pgv.stat(pgv.t('stock.stat_alertes'), v_nb_alerts::text, CASE WHEN v_nb_alerts > 0 THEN 'danger' ELSE NULL END),
    pgv.stat(pgv.t('stock.stat_mvt_semaine'), v_mvt_week::text || coalesce(' (' || v_variation || ')', ''))
  ]);

  IF v_nb_alerts > 0 THEN
    v_rows := ARRAY[]::text[];
    FOR r IN
      SELECT a.id, a.reference, a.description, a.unit, a.min_threshold, stock._current_stock(a.id) AS qty
      FROM stock.article a
      WHERE a.active AND a.min_threshold > 0
        AND stock._current_stock(a.id) < a.min_threshold
      ORDER BY (stock._current_stock(a.id) / a.min_threshold)
      LIMIT 10
    LOOP
      v_rows := v_rows || ARRAY[
        format('<a href="%s">%s</a>',
          pgv.call_ref('get_article', jsonb_build_object('p_id', r.id)),
          pgv.esc(r.description)),
        pgv.esc(r.reference),
        pgv.badge(r.qty::text || ' ' || r.unit, 'danger'),
        r.min_threshold::text || ' ' || r.unit
      ];
    END LOOP;
    v_body := v_body || '<h3>' || pgv.t('stock.title_stock_bas') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_article'), pgv.t('stock.col_ref'), pgv.t('stock.col_stock_actuel'), pgv.t('stock.col_seuil')],
      v_rows
    );
  END IF;

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.description, count(*) AS nb_mvt, sum(m.quantity) AS total_qty
    FROM stock.movement m
    JOIN stock.article a ON a.id = m.article_id
    WHERE m.created_at >= date_trunc('month', now())
    GROUP BY a.id, a.description
    ORDER BY nb_mvt DESC
    LIMIT 5
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>',
        pgv.call_ref('get_article', jsonb_build_object('p_id', r.id)),
        pgv.esc(r.description)),
      r.nb_mvt::text,
      r.total_qty::text
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>' || pgv.t('stock.title_top_articles') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_article'), pgv.t('stock.col_mouvements'), pgv.t('stock.col_qty_totale')],
      v_rows
    );
  END IF;

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT m.created_at, a.description, w.name AS warehouse_name, m.type, m.quantity, m.reference
    FROM stock.movement m
    JOIN stock.article a ON a.id = m.article_id
    JOIN stock.warehouse w ON w.id = m.warehouse_id
    ORDER BY m.created_at DESC
    LIMIT 10
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.created_at, 'DD/MM HH24:MI'),
      pgv.esc(r.description),
      pgv.esc(r.warehouse_name),
      pgv.badge(r.type, CASE r.type
        WHEN 'entry' THEN 'success'
        WHEN 'exit' THEN 'danger'
        WHEN 'transfer' THEN 'info'
        WHEN 'inventory' THEN 'warning'
      END),
      r.quantity::text,
      coalesce(r.reference, '')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('stock.empty_no_mouvement'), pgv.t('stock.empty_first_mouvement'));
  ELSE
    v_body := v_body || '<h3>' || pgv.t('stock.title_derniers_mvt') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_date'), pgv.t('stock.col_article'), pgv.t('stock.col_depot'), pgv.t('stock.col_type'), pgv.t('stock.col_qty'), pgv.t('stock.col_ref')],
      v_rows
    );
  END IF;

  v_body := v_body || '<p>' || pgv.form_dialog(
    'dlg-new-mvt', pgv.t('stock.btn_nouveau_mvt'), '', 'post_movement_save',
    NULL, NULL, pgv.call_ref('get_movement_form')
  ) || '</p>';

  RETURN v_body;
END;
$function$;
