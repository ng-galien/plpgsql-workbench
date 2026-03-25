CREATE OR REPLACE FUNCTION purchase.order_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_actions jsonb;
  v_has_receipts boolean;
BEGIN
  SELECT to_jsonb(o) || jsonb_build_object(
    'supplier_name', cl.name,
    'total_ht', purchase._total_ht(o.id),
    'total_tva', purchase._total_tva(o.id),
    'total_ttc', purchase._total_ttc(o.id),
    'line_count', (SELECT count(*) FROM purchase.order_line l WHERE l.order_id = o.id),
    'receipt_count', (SELECT count(*) FROM purchase.receipt r WHERE r.order_id = o.id)
  ) INTO v_result
  FROM purchase.purchase_order o
  JOIN crm.client cl ON cl.id = o.supplier_id
  WHERE o.id = p_id::int AND o.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;

  -- HATEOAS actions based on state
  v_actions := '[]'::jsonb;

  CASE v_result->>'status'
    WHEN 'draft' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'send', 'uri', 'purchase://purchase_order/' || p_id || '/send'),
        jsonb_build_object('method', 'cancel', 'uri', 'purchase://purchase_order/' || p_id || '/cancel'),
        jsonb_build_object('method', 'delete', 'uri', 'purchase://purchase_order/' || p_id)
      );
    WHEN 'sent', 'partially_received' THEN
      v_has_receipts := (v_result->'receipt_count')::int > 0;
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'receive', 'uri', 'purchase://purchase_order/' || p_id || '/receive')
      );
      IF NOT v_has_receipts THEN
        v_actions := v_actions || jsonb_build_array(
          jsonb_build_object('method', 'cancel', 'uri', 'purchase://purchase_order/' || p_id || '/cancel')
        );
      END IF;
    ELSE
      -- received, cancelled: no actions (terminal)
  END CASE;

  v_result := v_result || jsonb_build_object('actions', v_actions);

  RETURN v_result;
END;
$function$;
