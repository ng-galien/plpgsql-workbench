CREATE OR REPLACE FUNCTION purchase.post_receipt_create(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_order_id int := (p_data->>'p_commande_id')::int;
  v_status text;
  v_receipt_id int;
  v_number text;
  v_line_count int := 0;
  v_all_received bool;
  r record;
BEGIN
  SELECT status INTO v_status FROM purchase.purchase_order WHERE id = v_order_id;
  IF v_status NOT IN ('sent', 'partially_received') THEN
    RETURN pgv.toast(pgv.t('purchase.err_not_receivable'), 'error');
  END IF;

  v_number := purchase._next_number('REC');
  INSERT INTO purchase.receipt (order_id, number, notes)
  VALUES (v_order_id, v_number, coalesce(p_data->>'p_notes', ''))
  RETURNING id INTO v_receipt_id;

  FOR r IN
    SELECT l.id AS line_id, purchase._remaining_quantity(l.id) AS remaining
      FROM purchase.order_line l
     WHERE l.order_id = v_order_id
       AND purchase._remaining_quantity(l.id) > 0
  LOOP
    INSERT INTO purchase.receipt_line (reception_id, line_id, quantity_received)
    VALUES (v_receipt_id, r.line_id, r.remaining);
    v_line_count := v_line_count + 1;
  END LOOP;

  IF v_line_count = 0 THEN
    DELETE FROM purchase.receipt WHERE id = v_receipt_id;
    RETURN pgv.toast(pgv.t('purchase.err_all_received'), 'error');
  END IF;

  SELECT NOT exists(
    SELECT 1 FROM purchase.order_line l
     WHERE l.order_id = v_order_id
       AND purchase._remaining_quantity(l.id) > 0
  ) INTO v_all_received;

  IF v_all_received THEN
    UPDATE purchase.purchase_order SET status = 'received' WHERE id = v_order_id;
  ELSE
    UPDATE purchase.purchase_order SET status = 'partially_received' WHERE id = v_order_id;
  END IF;

  RETURN pgv.toast(format('Receipt %s created (%s lines)', v_number, v_line_count))
    || pgv.redirect(pgv.call_ref('get_order', jsonb_build_object('p_id', v_order_id)));
END;
$function$;
