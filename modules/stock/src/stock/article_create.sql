CREATE OR REPLACE FUNCTION stock.article_create(p_row stock.article)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.created_at := now();
  p_row.updated_at := now();

  INSERT INTO stock.article (tenant_id, reference, description, category, unit, purchase_price, wap, min_threshold, supplier_id, notes, active, created_at, updated_at, catalog_article_id)
  VALUES (p_row.tenant_id, p_row.reference, p_row.description, p_row.category, coalesce(p_row.unit, 'ea'), p_row.purchase_price, coalesce(p_row.wap, 0), coalesce(p_row.min_threshold, 0), p_row.supplier_id, coalesce(p_row.notes, ''), coalesce(p_row.active, true), p_row.created_at, p_row.updated_at, p_row.catalog_article_id)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
