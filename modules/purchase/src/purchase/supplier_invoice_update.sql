CREATE OR REPLACE FUNCTION purchase.supplier_invoice_update(p_row purchase.supplier_invoice)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE purchase.supplier_invoice SET
    supplier_ref = coalesce(nullif(p_row.supplier_ref, ''), supplier_ref),
    order_id = coalesce(p_row.order_id, order_id),
    amount_excl_tax = coalesce(p_row.amount_excl_tax, amount_excl_tax),
    amount_incl_tax = coalesce(p_row.amount_incl_tax, amount_incl_tax),
    invoice_date = coalesce(p_row.invoice_date, invoice_date),
    due_date = coalesce(p_row.due_date, due_date),
    notes = coalesce(p_row.notes, notes),
    updated_at = now()
  WHERE id = p_row.id
    AND tenant_id = current_setting('app.tenant_id', true)
    AND status = 'received'
  RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
