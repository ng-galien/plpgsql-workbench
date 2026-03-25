CREATE OR REPLACE FUNCTION stock.get_article(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_art stock.article;
  v_body text;
  v_rows text[];
  v_supplier text;
  v_supplier_link text;
  v_stock_total numeric;
  v_catalog_link text;
  r record;
BEGIN
  SELECT * INTO v_art FROM stock.article WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.empty(pgv.t('stock.empty_article_not_found'), ''); END IF;

  SELECT name INTO v_supplier FROM crm.client WHERE id = v_art.supplier_id;
  v_stock_total := stock._current_stock(p_id);

  IF v_supplier IS NOT NULL THEN
    v_supplier_link := format('<a href="/crm/client?p_id=%s">%s</a>', v_art.supplier_id, pgv.esc(v_supplier));
  ELSE
    v_supplier_link := '—';
  END IF;

  v_catalog_link := '—';
  IF v_art.catalog_article_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'catalog')
    AND EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'catalog' AND p.proname = 'get_article')
  THEN
    v_catalog_link := format('<a href="/catalog/article?p_id=%s">%s</a>', v_art.catalog_article_id, pgv.t('stock.cross_catalog_voir'));
  ELSIF v_art.catalog_article_id IS NOT NULL THEN
    v_catalog_link := format('#%s (%s)', v_art.catalog_article_id, pgv.t('stock.cross_catalog_unavailable'));
  END IF;

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('stock.stat_stock_total'), v_stock_total::text || ' ' || v_art.unit),
    pgv.stat(pgv.t('stock.stat_pmp'), CASE WHEN v_art.wap > 0 THEN to_char(v_art.wap, 'FM999G990D00') || ' EUR' ELSE '—' END),
    pgv.stat(pgv.t('stock.stat_seuil_mini'), CASE WHEN v_art.min_threshold > 0 THEN v_art.min_threshold::text || ' ' || v_art.unit ELSE '—' END),
    pgv.stat(pgv.t('stock.stat_fournisseur'), v_supplier_link)
  ]);

  v_body := v_body || format('<p><strong>%s</strong> %s | <strong>%s</strong> %s | <strong>%s</strong> %s</p>',
    pgv.t('stock.label_ref'), pgv.esc(v_art.reference),
    pgv.t('stock.label_categorie'), pgv.badge(v_art.category, NULL),
    pgv.t('stock.label_actif'), CASE WHEN v_art.active THEN pgv.t('stock.yes') ELSE pgv.t('stock.no') END
  );

  IF v_catalog_link <> '—' THEN
    v_body := v_body || format('<p><strong>%s</strong> %s</p>', pgv.t('stock.label_catalog'), v_catalog_link);
  END IF;

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT w.id, w.name, stock._current_stock(p_id, w.id) AS qty
    FROM stock.warehouse w
    WHERE w.active
      AND EXISTS (SELECT 1 FROM stock.movement m WHERE m.article_id = p_id AND m.warehouse_id = w.id)
    ORDER BY w.name
  LOOP
    v_rows := v_rows || ARRAY[pgv.esc(r.name), r.qty::text || ' ' || v_art.unit];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>' || pgv.t('stock.title_stock_depot') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_depot'), pgv.t('stock.col_quantite')], v_rows
    );
  END IF;

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT m.created_at, w.name AS warehouse_name, m.type, m.quantity, m.unit_price, m.reference
    FROM stock.movement m
    JOIN stock.warehouse w ON w.id = m.warehouse_id
    WHERE m.article_id = p_id
    ORDER BY m.created_at DESC LIMIT 20
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.created_at, 'DD/MM HH24:MI'), pgv.esc(r.warehouse_name),
      pgv.badge(r.type, CASE r.type WHEN 'entry' THEN 'success' WHEN 'exit' THEN 'danger' WHEN 'transfer' THEN 'info' WHEN 'inventory' THEN 'warning' END),
      r.quantity::text,
      CASE WHEN r.unit_price IS NOT NULL THEN to_char(r.unit_price, 'FM999G990D00') ELSE '—' END,
      coalesce(r.reference, '')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>' || pgv.t('stock.title_mvt_recents') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_date'), pgv.t('stock.col_depot'), pgv.t('stock.col_type'), pgv.t('stock.col_qty'), pgv.t('stock.col_pu'), pgv.t('stock.col_ref')],
      v_rows, 10
    );
  END IF;

  v_body := v_body || '<p>' || pgv.form_dialog(
    'dlg-edit-art-' || p_id, pgv.t('stock.btn_modifier'), '', 'post_article_save',
    pgv.t('stock.btn_modifier'), 'outline',
    pgv.call_ref('get_article_form', jsonb_build_object('p_id', p_id))
  ) || ' ';
  v_body := v_body || pgv.action('post_article_delete', pgv.t('stock.btn_desactiver'),
    jsonb_build_object('id', p_id), pgv.t('stock.confirm_desactiver')) || '</p>';

  RETURN v_body;
END;
$function$;
