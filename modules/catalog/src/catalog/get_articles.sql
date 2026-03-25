CREATE OR REPLACE FUNCTION catalog.get_articles(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_q text := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_category_id text := NULLIF(trim(COALESCE(p_params->>'category_id', '')), '');
  v_active text := NULLIF(trim(COALESCE(p_params->>'active', '')), '');
  v_body text;
  v_rows text[];
  v_cat_opts jsonb;
  r record;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object('value', c.id::text, 'label', c.name) ORDER BY c.name), '[]'::jsonb)
  INTO v_cat_opts FROM catalog.category c;

  v_body := '<form>'
    || '<div class="grid">'
    || pgv.input('q', 'search', pgv.t('catalog.field_search'), v_q)
    || pgv.sel('category_id', pgv.t('catalog.field_category'), v_cat_opts, COALESCE(v_category_id, ''))
    || pgv.sel('active', pgv.t('catalog.field_status'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('catalog.filter_active'), 'value', 'yes'),
         jsonb_build_object('label', pgv.t('catalog.filter_inactive'), 'value', 'no')
       ), COALESCE(v_active, ''))
    || '</div>'
    || '<button type="submit" class="outline">' || pgv.t('catalog.btn_filter') || '</button>'
    || '</form>';

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.reference, a.name, c.name AS category_name,
           a.sale_price, a.purchase_price, u.label AS unit_label, a.vat_rate, a.active
    FROM catalog.article a
    LEFT JOIN catalog.category c ON c.id = a.category_id
    LEFT JOIN catalog.unit u ON u.code = a.unit
    WHERE (v_q IS NULL OR a.name ILIKE '%' || v_q || '%' OR a.reference ILIKE '%' || v_q || '%')
      AND (v_category_id IS NULL OR a.category_id = v_category_id::int)
      AND (v_active IS NULL OR (v_active = 'yes' AND a.active) OR (v_active = 'no' AND NOT a.active))
    ORDER BY a.name
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
      CASE WHEN r.purchase_price IS NOT NULL
        THEN to_char(r.purchase_price, 'FM999G990D00') || ' EUR'
        ELSE '—' END,
      coalesce(r.unit_label, '—'),
      r.vat_rate || '%',
      CASE WHEN r.active THEN pgv.badge(pgv.t('catalog.badge_active'), 'success') ELSE pgv.badge(pgv.t('catalog.badge_inactive'), 'warning') END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('catalog.empty_no_article_found'), pgv.t('catalog.empty_adjust_filters'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('catalog.col_ref'), pgv.t('catalog.col_name'), pgv.t('catalog.col_category'), pgv.t('catalog.col_sale_price'), pgv.t('catalog.col_purchase_price'), pgv.t('catalog.col_unit'), pgv.t('catalog.col_vat_rate'), pgv.t('catalog.col_status')],
      v_rows, 20
    );
  END IF;

  v_body := v_body || format('<p><a href="%s" role="button">%s</a></p>',
    pgv.call_ref('get_article_form'), pgv.t('catalog.btn_new_article'));

  RETURN v_body;
END;
$function$;
