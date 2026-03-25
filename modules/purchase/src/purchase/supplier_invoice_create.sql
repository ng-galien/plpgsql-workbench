CREATE OR REPLACE FUNCTION purchase.supplier_invoice_create(p_row purchase.supplier_invoice)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO purchase.supplier_invoice (tenant_id, order_id, supplier_ref, amount_excl_tax, amount_incl_tax, invoice_date, due_date, notes)
  VALUES (
    current_setting('app.tenant_id', true),
    p_row.order_id,
    p_row.supplier_ref,
    p_row.amount_excl_tax,
    p_row.amount_incl_tax,
    p_row.invoice_date,
    p_row.due_date,
    coalesce(p_row.notes, '')
  )
  RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
