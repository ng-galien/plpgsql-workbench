CREATE OR REPLACE FUNCTION stock.get_articles()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  r record;
BEGIN
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.reference, a.description, a.category, a.unit,
           a.purchase_price, a.wap, a.min_threshold, a.active, a.supplier_id,
           stock._current_stock(a.id) AS qty,
           c.name AS supplier
    FROM stock.article a
    LEFT JOIN crm.client c ON c.id = a.supplier_id
    ORDER BY a.description
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_article', jsonb_build_object('p_id', r.id)), pgv.esc(r.reference)),
      pgv.esc(r.description),
      pgv.badge(r.category, CASE r.category
        WHEN 'wood' THEN 'success'
        WHEN 'hardware' THEN 'info'
        WHEN 'panel' THEN 'warning'
        ELSE NULL
      END),
      r.qty::text || ' ' || r.unit,
      CASE WHEN r.wap > 0 THEN to_char(r.wap, 'FM999G990D00') ELSE '—' END,
      CASE WHEN r.min_threshold > 0 AND r.qty < r.min_threshold
        THEN pgv.badge(pgv.t('stock.col_alerte'), 'danger')
        ELSE '—'
      END,
      CASE WHEN r.supplier IS NOT NULL
        THEN format('<a href="/crm/client?p_id=%s">%s</a>', r.supplier_id, pgv.esc(r.supplier))
        ELSE '—'
      END,
      CASE WHEN r.active THEN pgv.t('stock.yes') ELSE pgv.t('stock.no') END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty(pgv.t('stock.empty_no_article'), pgv.t('stock.empty_first_article'));
  ELSE
    v_body := pgv.md_table(
      ARRAY[pgv.t('stock.col_ref'), pgv.t('stock.col_designation'), pgv.t('stock.col_categorie'), pgv.t('stock.col_stock'), pgv.t('stock.col_pmp'), pgv.t('stock.col_alerte'), pgv.t('stock.col_fournisseur'), pgv.t('stock.col_actif')],
      v_rows, 20
    );
  END IF;

  v_body := v_body || '<p>' || pgv.form_dialog(
    'dlg-new-article', pgv.t('stock.btn_nouvel_article'), '', 'post_article_save',
    NULL, NULL, pgv.call_ref('get_article_form')
  ) || '</p>';

  RETURN v_body;
END;
$function$;
