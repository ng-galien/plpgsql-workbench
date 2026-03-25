CREATE OR REPLACE FUNCTION quote.post_invoice_delete(p_data jsonb)
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
  IF v_status <> 'draft' THEN RAISE EXCEPTION '%', pgv.t('quote.err_draft_delete_only'); END IF;

  DELETE FROM quote.invoice WHERE id = v_id;

  RETURN pgv.toast(pgv.t('quote.toast_invoice_deleted'))
    || pgv.redirect(pgv.call_ref('get_invoice'));
END;
$function$;
