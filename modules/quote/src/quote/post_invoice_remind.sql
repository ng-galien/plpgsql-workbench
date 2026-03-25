CREATE OR REPLACE FUNCTION quote.post_invoice_remind(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
  v_status text;
  v_days int;
BEGIN
  SELECT status, extract(day FROM now() - created_at)::int
    INTO v_status, v_days
    FROM quote.invoice WHERE id = v_id;

  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_invoice'); END IF;
  IF v_status <> 'sent' THEN
    RAISE EXCEPTION 'Only sent invoices can be reminded (current status: %)', v_status;
  END IF;
  IF v_days <= 30 THEN
    RAISE EXCEPTION 'Reminder only after 30 days (currently: % days)', v_days;
  END IF;

  UPDATE quote.invoice
     SET status = 'overdue',
         notes = notes || E'\n[Reminder ' || to_char(now(), 'DD/MM/YYYY') || ']'
   WHERE id = v_id;

  RETURN pgv.toast(pgv.t('quote.toast_invoice_reminded'))
      || pgv.redirect('/quote/invoice?p_id=' || v_id);
END;
$function$;
