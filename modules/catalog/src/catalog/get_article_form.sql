CREATE OR REPLACE FUNCTION catalog.get_article_form(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := nullif(p_params->>'p_id', '')::int;
  v_art catalog.article;
  v_body text;
  v_cat_opts jsonb;
  v_unit_opts jsonb;
  v_vat_opts jsonb;
BEGIN
  IF v_id IS NOT NULL THEN
    SELECT * INTO v_art FROM catalog.article WHERE id = v_id;
    IF NOT FOUND THEN RETURN pgv.empty(pgv.t('catalog.err_not_found')); END IF;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('value', c.id::text, 'label', c.name) ORDER BY c.name), '[]'::jsonb)
  INTO v_cat_opts FROM catalog.category c;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('value', u.code, 'label', u.label) ORDER BY u.label), '[]'::jsonb)
  INTO v_unit_opts FROM catalog.unit u;

  v_vat_opts := jsonb_build_array(
    jsonb_build_object('value', '20.00', 'label', '20%'),
    jsonb_build_object('value', '10.00', 'label', '10%'),
    jsonb_build_object('value', '5.50', 'label', '5,5%'),
    jsonb_build_object('value', '0.00', 'label', '0%')
  );

  v_body := CASE WHEN v_id IS NOT NULL
    THEN format('<input type="hidden" name="id" value="%s">', v_id)
    ELSE '' END;

  v_body := v_body || '<div class="grid">'
    || pgv.input('reference', 'text', pgv.t('catalog.field_reference'), v_art.reference)
    || pgv.input('name', 'text', pgv.t('catalog.field_name'), v_art.name, true)
    || '</div>'
    || '<div class="grid">'
    || pgv.sel('category_id', pgv.t('catalog.field_category'), v_cat_opts, v_art.category_id::text)
    || pgv.sel('unit', pgv.t('catalog.field_unit'), v_unit_opts, coalesce(v_art.unit, 'u'))
    || pgv.sel('vat_rate', pgv.t('catalog.field_vat_rate'), v_vat_opts, coalesce(v_art.vat_rate, 20.00)::text)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('sale_price', 'number', pgv.t('catalog.field_sale_price'),
         CASE WHEN v_art.sale_price IS NOT NULL THEN v_art.sale_price::text ELSE NULL END)
    || pgv.input('purchase_price', 'number', pgv.t('catalog.field_purchase_price'),
         CASE WHEN v_art.purchase_price IS NOT NULL THEN v_art.purchase_price::text ELSE NULL END)
    || '</div>'
    || pgv.textarea('description', pgv.t('catalog.field_description'), v_art.description);

  RETURN pgv.form(
    CASE WHEN v_id IS NOT NULL THEN 'post_article_update' ELSE 'post_article_create' END,
    v_body,
    CASE WHEN v_id IS NOT NULL THEN pgv.t('catalog.btn_edit') ELSE pgv.t('catalog.btn_create') END
  );
END;
$function$;
