CREATE OR REPLACE FUNCTION quote_ut.test_estimate_lifecycle()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_id int; v_status text; v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Create draft estimate
  v_result := quote.post_estimate_save(jsonb_build_object('client_id', (SELECT id FROM crm.client LIMIT 1), 'subject', 'Test lifecycle'));
  SELECT id INTO v_id FROM quote.estimate ORDER BY id DESC LIMIT 1;
  SELECT status INTO v_status FROM quote.estimate WHERE id = v_id;
  RETURN NEXT is(v_status, 'draft', 'New estimate is draft');

  -- Send
  PERFORM quote.post_estimate_send(jsonb_build_object('id', v_id));
  SELECT status INTO v_status FROM quote.estimate WHERE id = v_id;
  RETURN NEXT is(v_status, 'sent', 'Transition draft -> sent');

  -- Accept
  PERFORM quote.post_estimate_accept(jsonb_build_object('id', v_id));
  SELECT status INTO v_status FROM quote.estimate WHERE id = v_id;
  RETURN NEXT is(v_status, 'accepted', 'Transition sent -> accepted');

  -- Invalid transition
  RETURN NEXT throws_ok(
    format('SELECT quote.post_estimate_send(''{"id":%s}''::jsonb)', v_id),
    'Invalid transition: accepted -> sent'
  );

  -- Test decline path
  v_result := quote.post_estimate_save(jsonb_build_object('client_id', (SELECT id FROM crm.client LIMIT 1), 'subject', 'Decline test'));
  SELECT id INTO v_id FROM quote.estimate ORDER BY id DESC LIMIT 1;
  PERFORM quote.post_estimate_send(jsonb_build_object('id', v_id));
  PERFORM quote.post_estimate_decline(jsonb_build_object('id', v_id));
  SELECT status INTO v_status FROM quote.estimate WHERE id = v_id;
  RETURN NEXT is(v_status, 'declined', 'Transition sent -> declined');
END;
$function$;
