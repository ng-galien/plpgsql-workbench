CREATE OR REPLACE FUNCTION catalog.article_update(p_row catalog.article)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE catalog.article SET
    reference = COALESCE(p_row.reference, reference),
    name = COALESCE(p_row.name, name),
    description = COALESCE(p_row.description, description),
    category_id = COALESCE(p_row.category_id, category_id),
    unit = COALESCE(p_row.unit, unit),
    sale_price = COALESCE(p_row.sale_price, sale_price),
    purchase_price = COALESCE(p_row.purchase_price, purchase_price),
    vat_rate = COALESCE(p_row.vat_rate, vat_rate),
    active = COALESCE(p_row.active, active),
    updated_at = now()
  WHERE id = p_row.id
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
