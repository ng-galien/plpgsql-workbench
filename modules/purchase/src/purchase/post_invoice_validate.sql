CREATE OR REPLACE FUNCTION purchase.post_invoice_validate(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
BEGIN
  UPDATE purchase.supplier_invoice SET status = 'validated'
   WHERE id = v_id AND status = 'received';

  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('purchase.err_invoice_already_validated'), 'error');
  END IF;

  RETURN pgv.toast(pgv.t('purchase.toast_invoice_validated'))
    || pgv.redirect(pgv.call_ref('get_supplier_invoice', jsonb_build_object('p_id', v_id)));
END;
$function$;
