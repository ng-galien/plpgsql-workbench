CREATE OR REPLACE FUNCTION purchase.supplier_invoice_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_actions jsonb;
BEGIN
  SELECT to_jsonb(i) || jsonb_build_object(
    'order_number', o.number,
    'supplier_name', cl.name,
    'supplier_id', cl.id,
    'order_ttc', CASE WHEN i.order_id IS NOT NULL THEN purchase._total_ttc(i.order_id) END,
    'variance', CASE WHEN i.order_id IS NOT NULL THEN i.amount_incl_tax - purchase._total_ttc(i.order_id) END
  ) INTO v_result
  FROM purchase.supplier_invoice i
  LEFT JOIN purchase.purchase_order o ON o.id = i.order_id
  LEFT JOIN crm.client cl ON cl.id = o.supplier_id
  WHERE i.id = p_id::int AND i.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN
    RETURN NULL;
  END IF;

  v_actions := '[]'::jsonb;

  CASE v_result->>'status'
    WHEN 'received' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'validate', 'uri', 'purchase://supplier_invoice/' || p_id || '/validate'),
        jsonb_build_object('method', 'delete', 'uri', 'purchase://supplier_invoice/' || p_id)
      );
    WHEN 'validated' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'pay', 'uri', 'purchase://supplier_invoice/' || p_id || '/pay')
      );
    WHEN 'paid' THEN
      IF NOT (v_result->>'posted')::boolean THEN
        v_actions := jsonb_build_array(
          jsonb_build_object('method', 'post', 'uri', 'purchase://supplier_invoice/' || p_id || '/post')
        );
      END IF;
    ELSE
      -- terminal
  END CASE;

  v_result := v_result || jsonb_build_object('actions', v_actions);
  RETURN v_result;
END;
$function$;
