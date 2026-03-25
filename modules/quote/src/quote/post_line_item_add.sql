CREATE OR REPLACE FUNCTION quote.post_line_item_add(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_estimate_id int;
  v_invoice_id int;
  v_redirect text;
  v_article_id int;
  v_description text;
  v_unit_price numeric;
  v_tva_rate numeric;
  v_unit text;
  v_art record;
BEGIN
  v_estimate_id := (p_data->>'estimate_id')::int;
  v_invoice_id := (p_data->>'invoice_id')::int;
  v_article_id := (p_data->>'article_id')::int;

  -- Initialize v_art to avoid "record not assigned" on field access
  SELECT NULL::text AS label, NULL::numeric AS price, NULL::text AS art_unit, NULL::numeric AS vat INTO v_art;

  -- Verify parent is draft
  IF v_estimate_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM quote.estimate WHERE id = v_estimate_id AND status = 'draft') THEN
      RAISE EXCEPTION '%', pgv.t('quote.err_draft_lines_only');
    END IF;
    v_redirect := pgv.call_ref('get_estimate', jsonb_build_object('p_id', v_estimate_id));
  ELSIF v_invoice_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM quote.invoice WHERE id = v_invoice_id AND status = 'draft') THEN
      RAISE EXCEPTION '%', pgv.t('quote.err_draft_lines_only');
    END IF;
    v_redirect := pgv.call_ref('get_invoice', jsonb_build_object('p_id', v_invoice_id));
  ELSE
    RAISE EXCEPTION '%', pgv.t('quote.err_parent_required');
  END IF;

  -- Lookup article if selected (catalog > stock)
  IF v_article_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM pg_namespace n
      JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = 'article'
     WHERE n.nspname = 'catalog'
    ) THEN
      EXECUTE
        'SELECT name AS label, sale_price AS price, unit AS art_unit, vat_rate AS vat
         FROM catalog.article WHERE id = $1 AND active'
      INTO v_art USING v_article_id;
    END IF;
    IF v_art.label IS NULL AND EXISTS (
      SELECT 1 FROM pg_namespace n
      JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = 'article'
     WHERE n.nspname = 'stock'
    ) THEN
      EXECUTE
        'SELECT description AS label, purchase_price AS price, unit AS art_unit, NULL::numeric AS vat
         FROM stock.article WHERE id = $1 AND active = true'
      INTO v_art USING v_article_id;
    END IF;
  END IF;

  -- Resolve values: form > article > defaults
  v_description := coalesce(
    nullif(trim(p_data->>'description'), ''),
    CASE WHEN v_article_id IS NOT NULL THEN v_art.label END,
    pgv.t('quote.err_default_description')
  );
  v_unit_price := coalesce(
    nullif((p_data->>'unit_price')::numeric, 0),
    CASE WHEN v_article_id IS NOT NULL THEN v_art.price END,
    0
  );
  v_unit := coalesce(
    nullif(p_data->>'unit', ''),
    CASE WHEN v_article_id IS NOT NULL THEN v_art.art_unit END,
    'u'
  );
  v_tva_rate := coalesce((p_data->>'tva_rate')::numeric, CASE WHEN v_article_id IS NOT NULL THEN v_art.vat END, 20.00);

  INSERT INTO quote.line_item (estimate_id, invoice_id, description, quantity, unit, unit_price, tva_rate)
  VALUES (
    v_estimate_id,
    v_invoice_id,
    v_description,
    coalesce((p_data->>'quantity')::numeric, 1),
    v_unit,
    v_unit_price,
    v_tva_rate
  );

  RETURN pgv.toast(pgv.t('quote.toast_line_added'))
    || pgv.redirect(v_redirect);
END;
$function$;
