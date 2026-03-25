CREATE OR REPLACE FUNCTION purchase.order_create(p_row purchase.purchase_order)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO purchase.purchase_order (tenant_id, number, supplier_id, subject, notes, delivery_date, payment_terms)
  VALUES (
    current_setting('app.tenant_id', true),
    purchase._next_number('PO'),
    p_row.supplier_id,
    p_row.subject,
    coalesce(p_row.notes, ''),
    p_row.delivery_date,
    coalesce(p_row.payment_terms, '')
  )
  RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
