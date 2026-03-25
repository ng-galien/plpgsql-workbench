CREATE OR REPLACE FUNCTION purchase.post_line_remove(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_line_id int := (p_data->>'p_ligne_id')::int;
  v_order_id int;
  v_status text;
BEGIN
  SELECT l.order_id, o.status INTO v_order_id, v_status
    FROM purchase.order_line l
    JOIN purchase.purchase_order o ON o.id = l.order_id
   WHERE l.id = v_line_id;

  IF v_status IS NULL OR v_status <> 'draft' THEN
    RETURN pgv.toast(pgv.t('purchase.err_draft_only'), 'error');
  END IF;

  DELETE FROM purchase.order_line WHERE id = v_line_id;

  RETURN pgv.toast(pgv.t('purchase.toast_line_removed'))
    || pgv.redirect(pgv.call_ref('get_order', jsonb_build_object('p_id', v_order_id)));
END;
$function$;
