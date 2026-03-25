CREATE OR REPLACE FUNCTION quote.post_estimate_send(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'id')::int;
  v_status text;
BEGIN
  SELECT status INTO v_status FROM quote.estimate WHERE id = v_id;
  IF v_status IS NULL THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_estimate'); END IF;
  IF v_status <> 'draft' THEN RAISE EXCEPTION 'Invalid transition: % -> sent', v_status; END IF;

  UPDATE quote.estimate SET status = 'sent' WHERE id = v_id;

  RETURN pgv.toast(pgv.t('quote.toast_estimate_sent'))
    || pgv.redirect(pgv.call_ref('get_estimate', jsonb_build_object('p_id', v_id)));
END;
$function$;
