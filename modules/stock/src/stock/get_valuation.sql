CREATE OR REPLACE FUNCTION stock.get_valuation()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_total_value numeric;
  v_nb_articles int;
  v_nb_alerts int;
  v_rows text[];
  r record;
BEGIN
  SELECT count(*)::int INTO v_nb_articles FROM stock.article WHERE active;

  SELECT coalesce(sum(stock._current_stock(a.id) * a.wap), 0)
  INTO v_total_value
  FROM stock.article a WHERE a.active AND a.wap > 0;

  SELECT count(*)::int INTO v_nb_alerts
  FROM stock.article a
  WHERE a.active AND a.min_threshold > 0
    AND stock._current_stock(a.id) < a.min_threshold;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('stock.stat_valeur_totale'), to_char(v_total_value, 'FM999G999G990D00') || ' EUR'),
    pgv.stat(pgv.t('stock.stat_articles_stock'), v_nb_articles::text),
    pgv.stat(pgv.t('stock.stat_en_alerte'), v_nb_alerts::text, CASE WHEN v_nb_alerts > 0 THEN 'danger' ELSE NULL END)
  ]);

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT w.name AS warehouse_name, w.type AS warehouse_type,
           count(DISTINCT m.article_id)::int AS nb_articles,
           coalesce(sum(m.quantity * a.wap), 0) AS value
    FROM stock.warehouse w
    LEFT JOIN stock.movement m ON m.warehouse_id = w.id
    LEFT JOIN stock.article a ON a.id = m.article_id AND a.active
    WHERE w.active
    GROUP BY w.id, w.name, w.type
    ORDER BY value DESC
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.esc(r.warehouse_name),
      pgv.badge(r.warehouse_type, CASE r.warehouse_type
        WHEN 'storage' THEN 'info' WHEN 'workshop' THEN 'success' WHEN 'job_site' THEN 'warning' WHEN 'vehicle' THEN 'primary'
      END),
      r.nb_articles::text,
      to_char(r.value, 'FM999G999G990D00') || ' EUR'
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>' || pgv.t('stock.title_par_depot') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_depot'), pgv.t('stock.col_type'), pgv.t('stock.col_articles'), pgv.t('stock.col_valeur')], v_rows);
  END IF;

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.category, count(*)::int AS nb_articles,
           coalesce(sum(stock._current_stock(a.id) * a.wap), 0) AS value
    FROM stock.article a WHERE a.active AND a.wap > 0
    GROUP BY a.category ORDER BY value DESC
  LOOP
    v_rows := v_rows || ARRAY[
      pgv.badge(r.category, CASE r.category
        WHEN 'wood' THEN 'success' WHEN 'hardware' THEN 'info' WHEN 'panel' THEN 'warning' WHEN 'insulation' THEN 'primary' WHEN 'finish' THEN 'default' ELSE NULL
      END),
      r.nb_articles::text,
      to_char(r.value, 'FM999G999G990D00') || ' EUR'
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>' || pgv.t('stock.title_par_categorie') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_categorie'), pgv.t('stock.col_articles'), pgv.t('stock.col_valeur')], v_rows);
  END IF;

  RETURN v_body;
END;
$function$;
