CREATE OR REPLACE FUNCTION purchase.supplier_invoice_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(i) || jsonb_build_object('order_number', o.number, 'supplier_name', cl.name, 'supplier_id', cl.id)
      FROM purchase.supplier_invoice i
      LEFT JOIN purchase.purchase_order o ON o.id = i.order_id
      LEFT JOIN crm.client cl ON cl.id = o.supplier_id
      WHERE i.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY i.created_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(i) || jsonb_build_object(''order_number'', o.number, ''supplier_name'', cl.name, ''supplier_id'', cl.id)
       FROM purchase.supplier_invoice i
       LEFT JOIN purchase.purchase_order o ON o.id = i.order_id
       LEFT JOIN crm.client cl ON cl.id = o.supplier_id
       WHERE i.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
       || ' AND ' || pgv.rsql_to_where(p_filter, 'purchase', 'supplier_invoice')
       || ' ORDER BY i.created_at DESC';
  END IF;
END;
$function$;
