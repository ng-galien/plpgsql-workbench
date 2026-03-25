CREATE OR REPLACE FUNCTION purchase.order_update(p_row purchase.purchase_order)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE purchase.purchase_order SET
    supplier_id = coalesce(p_row.supplier_id, supplier_id),
    subject = coalesce(nullif(p_row.subject, ''), subject),
    notes = coalesce(p_row.notes, notes),
    delivery_date = coalesce(p_row.delivery_date, delivery_date),
    payment_terms = coalesce(p_row.payment_terms, payment_terms),
    updated_at = now()
  WHERE id = p_row.id
    AND tenant_id = current_setting('app.tenant_id', true)
    AND status = 'draft'
  RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
