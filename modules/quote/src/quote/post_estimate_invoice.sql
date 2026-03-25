CREATE OR REPLACE FUNCTION quote.post_estimate_invoice(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_estimate_id int := (p_data->>'id')::int;
  v_invoice_id int;
  v_number text;
  d record;
BEGIN
  SELECT * INTO d FROM quote.estimate WHERE id = v_estimate_id;
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_estimate'); END IF;
  IF d.status <> 'accepted' THEN RAISE EXCEPTION '%', pgv.t('quote.err_accepted_only'); END IF;

  v_number := quote._next_number('INV');

  INSERT INTO quote.invoice (number, client_id, estimate_id, subject, notes)
  VALUES (v_number, d.client_id, v_estimate_id, d.subject, d.notes)
  RETURNING id INTO v_invoice_id;

  INSERT INTO quote.line_item (invoice_id, sort_order, description, quantity, unit, unit_price, tva_rate)
  SELECT v_invoice_id, sort_order, description, quantity, unit, unit_price, tva_rate
    FROM quote.line_item WHERE estimate_id = v_estimate_id
   ORDER BY sort_order, id;

  RETURN pgv.toast(pgv.t('quote.toast_invoice_created') || ' ' || v_number)
    || pgv.redirect(pgv.call_ref('get_invoice', jsonb_build_object('p_id', v_invoice_id)));
END;
$function$;
