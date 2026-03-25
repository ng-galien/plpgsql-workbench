CREATE OR REPLACE FUNCTION quote.post_invoice_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int;
  v_number text;
BEGIN
  IF p_data->>'id' IS NOT NULL THEN
    v_id := (p_data->>'id')::int;
    IF NOT EXISTS (SELECT 1 FROM quote.invoice WHERE id = v_id AND status = 'draft') THEN
      RAISE EXCEPTION '%', pgv.t('quote.err_draft_only');
    END IF;
    UPDATE quote.invoice SET
      client_id = (p_data->>'client_id')::int,
      subject = p_data->>'subject',
      notes = coalesce(p_data->>'notes', '')
    WHERE id = v_id;
  ELSE
    v_number := quote._next_number('INV');
    INSERT INTO quote.invoice (number, client_id, subject, notes)
    VALUES (
      v_number,
      (p_data->>'client_id')::int,
      p_data->>'subject',
      coalesce(p_data->>'notes', '')
    ) RETURNING id INTO v_id;
  END IF;

  RETURN pgv.toast(pgv.t('quote.toast_invoice_saved'))
    || pgv.redirect(pgv.call_ref('get_invoice', jsonb_build_object('p_id', v_id)));
END;
$function$;
