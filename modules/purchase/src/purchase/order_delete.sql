CREATE OR REPLACE FUNCTION purchase.order_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row purchase.purchase_order;
BEGIN
  DELETE FROM purchase.purchase_order
  WHERE id = p_id::int
    AND tenant_id = current_setting('app.tenant_id', true)
    AND status = 'draft'
  RETURNING * INTO v_row;
  RETURN to_jsonb(v_row);
END;
$function$;
