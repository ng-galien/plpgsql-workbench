CREATE OR REPLACE FUNCTION purchase.supplier_invoice_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row purchase.supplier_invoice;
BEGIN
  DELETE FROM purchase.supplier_invoice
  WHERE id = p_id::int
    AND tenant_id = current_setting('app.tenant_id', true)
    AND status = 'received'
  RETURNING * INTO v_row;
  RETURN to_jsonb(v_row);
END;
$function$;
