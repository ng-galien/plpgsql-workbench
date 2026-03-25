CREATE OR REPLACE FUNCTION stock.article_update(p_row stock.article)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE stock.article SET
    reference = COALESCE(NULLIF(p_row.reference, ''), reference),
    description = COALESCE(NULLIF(p_row.description, ''), description),
    category = COALESCE(NULLIF(p_row.category, ''), category),
    unit = COALESCE(NULLIF(p_row.unit, ''), unit),
    purchase_price = COALESCE(p_row.purchase_price, purchase_price),
    min_threshold = COALESCE(p_row.min_threshold, min_threshold),
    supplier_id = COALESCE(p_row.supplier_id, supplier_id),
    notes = COALESCE(p_row.notes, notes),
    active = COALESCE(p_row.active, active),
    catalog_article_id = COALESCE(p_row.catalog_article_id, catalog_article_id),
    updated_at = now()
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
