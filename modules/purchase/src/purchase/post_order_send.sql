CREATE OR REPLACE FUNCTION purchase.post_order_send(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
BEGIN
  UPDATE purchase.purchase_order SET status = 'sent'
   WHERE id = v_id AND status = 'draft';

  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('purchase.err_already_sent'), 'error');
  END IF;

  RETURN pgv.toast(pgv.t('purchase.toast_order_sent'))
    || pgv.redirect(pgv.call_ref('get_order', jsonb_build_object('p_id', v_id)));
END;
$function$;
