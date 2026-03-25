CREATE OR REPLACE FUNCTION quote_ut.test_invoice_lifecycle()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_id int; v_status text; v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Create draft invoice
  v_result := quote.post_invoice_save(jsonb_build_object('client_id', (SELECT id FROM crm.client LIMIT 1), 'subject', 'Test lifecycle'));
  SELECT id INTO v_id FROM quote.invoice ORDER BY id DESC LIMIT 1;
  SELECT status INTO v_status FROM quote.invoice WHERE id = v_id;
  RETURN NEXT is(v_status, 'draft', 'New invoice is draft');

  -- Send
  PERFORM quote.post_invoice_send(jsonb_build_object('id', v_id));
  SELECT status INTO v_status FROM quote.invoice WHERE id = v_id;
  RETURN NEXT is(v_status, 'sent', 'Transition draft -> sent');

  -- Pay
  PERFORM quote.post_invoice_pay(jsonb_build_object('id', v_id));
  SELECT status INTO v_status FROM quote.invoice WHERE id = v_id;
  RETURN NEXT is(v_status, 'paid', 'Transition sent -> paid');
  RETURN NEXT isnt((SELECT paid_at FROM quote.invoice WHERE id = v_id), NULL, 'paid_at set');

  -- Invalid transition
  RETURN NEXT throws_ok(
    format('SELECT quote.post_invoice_send(''{"id":%s}''::jsonb)', v_id),
    'Invalid transition: paid -> sent'
  );

  -- Draft delete only
  RETURN NEXT throws_ok(
    format('SELECT quote.post_invoice_delete(''{"id":%s}''::jsonb)', v_id),
    'Seuls les brouillons peuvent être supprimés'
  );
END;
$function$;
