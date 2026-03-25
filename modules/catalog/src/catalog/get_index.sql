CREATE OR REPLACE FUNCTION catalog.get_index(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_nb_articles int;
  v_nb_categories int;
  v_avg_price numeric;
  v_body text;
  v_rows text[];
  r record;
BEGIN
  SELECT count(*)::int INTO v_nb_articles FROM catalog.article WHERE active;
  SELECT count(*)::int INTO v_nb_categories FROM catalog.category;
  SELECT coalesce(round(avg(sale_price), 2), 0) INTO v_avg_price
  FROM catalog.article WHERE active AND sale_price IS NOT NULL;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('catalog.stat_active_articles'), v_nb_articles::text),
    pgv.stat(pgv.t('catalog.stat_categories'), v_nb_categories::text),
    pgv.stat(pgv.t('catalog.stat_avg_sale_price'), to_char(v_avg_price, 'FM999G990D00') || ' EUR HT')
  ]);

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.reference, a.name, c.name AS category_name,
           a.sale_price, a.unit, a.active
    FROM catalog.article a
    LEFT JOIN catalog.category c ON c.id = a.category_id
    ORDER BY a.created_at DESC
    LIMIT 10
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>',
        pgv.call_ref('get_article', jsonb_build_object('p_id', r.id)),
        pgv.esc(coalesce(r.reference, '#' || r.id))),
      pgv.esc(r.name),
      coalesce(pgv.badge(r.category_name), '—'),
      CASE WHEN r.sale_price IS NOT NULL
        THEN to_char(r.sale_price, 'FM999G990D00') || ' EUR'
        ELSE '—' END,
      r.unit,
      CASE WHEN r.active THEN pgv.badge(pgv.t('catalog.badge_active'), 'success') ELSE pgv.badge(pgv.t('catalog.badge_inactive'), 'warning') END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('catalog.empty_no_article'), pgv.t('catalog.empty_first_article'));
  ELSE
    v_body := v_body || '<h3>' || pgv.t('catalog.title_recent') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('catalog.col_ref'), pgv.t('catalog.col_name'), pgv.t('catalog.col_category'), pgv.t('catalog.col_sale_price'), pgv.t('catalog.col_unit'), pgv.t('catalog.col_status')],
      v_rows
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">%s</a></p>',
    pgv.call_ref('get_article_form'), pgv.t('catalog.btn_new_article'));

  RETURN v_body;
END;
$function$;
