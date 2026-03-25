CREATE OR REPLACE FUNCTION quote.post_estimate_duplicate(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_src_id int := (p_data->>'id')::int;
  v_new_id int;
  v_number text;
  d record;
BEGIN
  SELECT * INTO d FROM quote.estimate WHERE id = v_src_id;
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_estimate'); END IF;

  v_number := quote._next_number('EST');

  INSERT INTO quote.estimate (number, client_id, subject, validity_days, notes)
  VALUES (v_number, d.client_id, d.subject, d.validity_days, d.notes)
  RETURNING id INTO v_new_id;

  INSERT INTO quote.line_item (estimate_id, sort_order, description, quantity, unit, unit_price, tva_rate)
  SELECT v_new_id, sort_order, description, quantity, unit, unit_price, tva_rate
    FROM quote.line_item WHERE estimate_id = v_src_id
   ORDER BY sort_order, id;

  RETURN pgv.toast(pgv.t('quote.toast_estimate_duplicated') || ' : ' || v_number)
    || pgv.redirect(pgv.call_ref('get_estimate', jsonb_build_object('p_id', v_new_id)));
END;
$function$;
