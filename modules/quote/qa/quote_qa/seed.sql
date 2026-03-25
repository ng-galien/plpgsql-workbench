CREATE OR REPLACE FUNCTION quote_qa.seed()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_client1 int;
  v_client2 int;
  v_client3 int;
  v_e1 int;
  v_e2 int;
  v_e3 int;
  v_i1 int;
  v_i2 int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  DELETE FROM quote.line_item;
  DELETE FROM quote.invoice;
  DELETE FROM quote.estimate;

  SELECT id INTO v_client1 FROM crm.client ORDER BY id LIMIT 1;
  SELECT id INTO v_client2 FROM crm.client ORDER BY id LIMIT 1 OFFSET 1;
  SELECT id INTO v_client3 FROM crm.client ORDER BY id LIMIT 1 OFFSET 2;
  IF v_client3 IS NULL THEN v_client3 := v_client1; END IF;
  IF v_client2 IS NULL THEN v_client2 := v_client1; END IF;

  -- Estimate 1: draft
  PERFORM quote.post_estimate_save(jsonb_build_object(
    'client_id', v_client1, 'subject', 'Kitchen renovation',
    'validity_days', 30, 'notes', 'Preliminary estimate, to confirm after visit.'
  ));
  SELECT id INTO v_e1 FROM quote.estimate ORDER BY id DESC LIMIT 1;

  PERFORM quote.post_line_item_add(jsonb_build_object('estimate_id', v_e1, 'description', 'Remove old furniture', 'quantity', 1, 'unit', 'flat', 'unit_price', 250, 'tva_rate', 10));
  PERFORM quote.post_line_item_add(jsonb_build_object('estimate_id', v_e1, 'description', 'Install new furniture', 'quantity', 12, 'unit', 'h', 'unit_price', 45, 'tva_rate', 10));
  PERFORM quote.post_line_item_add(jsonb_build_object('estimate_id', v_e1, 'description', 'Tile backsplash', 'quantity', 3.5, 'unit', 'm2', 'unit_price', 65, 'tva_rate', 20));

  -- Estimate 2: sent
  PERFORM quote.post_estimate_save(jsonb_build_object(
    'client_id', v_client2, 'subject', 'Living room + bedroom painting',
    'validity_days', 45
  ));
  SELECT id INTO v_e2 FROM quote.estimate ORDER BY id DESC LIMIT 1;

  PERFORM quote.post_line_item_add(jsonb_build_object('estimate_id', v_e2, 'description', 'Wall preparation (plaster + sanding)', 'quantity', 55, 'unit', 'm2', 'unit_price', 12, 'tva_rate', 10));
  PERFORM quote.post_line_item_add(jsonb_build_object('estimate_id', v_e2, 'description', '2-coat painting', 'quantity', 55, 'unit', 'm2', 'unit_price', 18, 'tva_rate', 10));
  PERFORM quote.post_line_item_add(jsonb_build_object('estimate_id', v_e2, 'description', 'Paint supply', 'quantity', 6, 'unit', 'u', 'unit_price', 42, 'tva_rate', 20));

  PERFORM quote.post_estimate_send(jsonb_build_object('id', v_e2));

  -- Estimate 3: accepted
  PERFORM quote.post_estimate_save(jsonb_build_object(
    'client_id', v_client3, 'subject', 'Bathroom plumbing installation',
    'validity_days', 30, 'notes', 'Site access: code 4521B'
  ));
  SELECT id INTO v_e3 FROM quote.estimate ORDER BY id DESC LIMIT 1;

  PERFORM quote.post_line_item_add(jsonb_build_object('estimate_id', v_e3, 'description', 'Remove existing fixtures', 'quantity', 4, 'unit', 'h', 'unit_price', 45, 'tva_rate', 10));
  PERFORM quote.post_line_item_add(jsonb_build_object('estimate_id', v_e3, 'description', 'Copper piping', 'quantity', 8, 'unit', 'm', 'unit_price', 28, 'tva_rate', 20));
  PERFORM quote.post_line_item_add(jsonb_build_object('estimate_id', v_e3, 'description', 'Walk-in shower installation', 'quantity', 1, 'unit', 'flat', 'unit_price', 850, 'tva_rate', 10));
  PERFORM quote.post_line_item_add(jsonb_build_object('estimate_id', v_e3, 'description', 'Faucets', 'quantity', 3, 'unit', 'u', 'unit_price', 120, 'tva_rate', 20));

  PERFORM quote.post_estimate_send(jsonb_build_object('id', v_e3));
  PERFORM quote.post_estimate_accept(jsonb_build_object('id', v_e3));

  -- Invoice 1: sent (from estimate 3)
  PERFORM quote.post_estimate_invoice(jsonb_build_object('id', v_e3));
  SELECT id INTO v_i1 FROM quote.invoice WHERE estimate_id = v_e3;
  PERFORM quote.post_invoice_send(jsonb_build_object('id', v_i1));

  -- Invoice 2: paid (direct)
  PERFORM quote.post_invoice_save(jsonb_build_object(
    'client_id', v_client1, 'subject', 'Emergency faucet repair',
    'notes', 'Urgent Saturday morning call'
  ));
  SELECT id INTO v_i2 FROM quote.invoice WHERE estimate_id IS NULL ORDER BY id DESC LIMIT 1;

  PERFORM quote.post_line_item_add(jsonb_build_object('invoice_id', v_i2, 'description', 'Travel', 'quantity', 1, 'unit', 'flat', 'unit_price', 50, 'tva_rate', 20));
  PERFORM quote.post_line_item_add(jsonb_build_object('invoice_id', v_i2, 'description', 'Labor', 'quantity', 1.5, 'unit', 'h', 'unit_price', 55, 'tva_rate', 10));
  PERFORM quote.post_line_item_add(jsonb_build_object('invoice_id', v_i2, 'description', 'Seal + fitting', 'quantity', 1, 'unit', 'u', 'unit_price', 15, 'tva_rate', 20));

  PERFORM quote.post_invoice_send(jsonb_build_object('id', v_i2));
  PERFORM quote.post_invoice_pay(jsonb_build_object('id', v_i2));

  RETURN 'quote_qa.seed: 3 estimates (draft/sent/accepted) + 2 invoices (sent/paid) + varied lines';
END;
$function$;
