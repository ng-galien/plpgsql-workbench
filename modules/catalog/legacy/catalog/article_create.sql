CREATE OR REPLACE FUNCTION catalog.article_create(p_row catalog.article)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.active := COALESCE(p_row.active, true);
  p_row.unit := COALESCE(p_row.unit, 'u');
  p_row.vat_rate := COALESCE(p_row.vat_rate, 20.00);
  p_row.created_at := now();
  p_row.updated_at := now();

  INSERT INTO catalog.article (reference, name, description, category_id, unit, sale_price, purchase_price, vat_rate, active, created_at, updated_at)
  VALUES (p_row.reference, p_row.name, p_row.description, p_row.category_id, p_row.unit, p_row.sale_price, p_row.purchase_price, p_row.vat_rate, p_row.active, p_row.created_at, p_row.updated_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
