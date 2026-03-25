CREATE OR REPLACE FUNCTION purchase.post_invoice_pay(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
BEGIN
  UPDATE purchase.supplier_invoice SET status = 'paid'
   WHERE id = v_id AND status = 'validated';

  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('purchase.err_invoice_not_validated'), 'error');
  END IF;

  RETURN pgv.toast(pgv.t('purchase.toast_invoice_paid'))
    || pgv.redirect(pgv.call_ref('get_supplier_invoice', jsonb_build_object('p_id', v_id)));
END;
$function$;
