CREATE OR REPLACE FUNCTION purchase.post_order_cancel(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
  v_has_receipts bool;
BEGIN
  SELECT exists(SELECT 1 FROM purchase.receipt WHERE order_id = v_id) INTO v_has_receipts;

  IF v_has_receipts THEN
    RETURN pgv.toast(pgv.t('purchase.err_cancel_receipts'), 'error');
  END IF;

  UPDATE purchase.purchase_order SET status = 'cancelled'
   WHERE id = v_id AND status IN ('draft', 'sent');

  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('purchase.err_not_cancellable'), 'error');
  END IF;

  RETURN pgv.toast(pgv.t('purchase.toast_order_cancelled'))
    || pgv.redirect(pgv.call_ref('get_order', jsonb_build_object('p_id', v_id)));
END;
$function$;
