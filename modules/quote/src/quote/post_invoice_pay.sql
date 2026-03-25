CREATE OR REPLACE FUNCTION quote.post_invoice_pay(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'id')::int;
  v_status text;
BEGIN
  SELECT status INTO v_status FROM quote.invoice WHERE id = v_id;
  IF v_status IS NULL THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_invoice'); END IF;
  IF v_status NOT IN ('sent', 'overdue') THEN RAISE EXCEPTION 'Invalid transition: % -> paid', v_status; END IF;

  UPDATE quote.invoice SET status = 'paid', paid_at = now() WHERE id = v_id;

  RETURN pgv.toast(pgv.t('quote.toast_invoice_paid'))
    || pgv.redirect(pgv.call_ref('get_invoice', jsonb_build_object('p_id', v_id)));
END;
$function$;
