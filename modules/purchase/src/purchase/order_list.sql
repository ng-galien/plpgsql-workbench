CREATE OR REPLACE FUNCTION purchase.order_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(o) || jsonb_build_object('supplier_name', cl.name, 'total_ttc', purchase._total_ttc(o.id))
      FROM purchase.purchase_order o
      JOIN crm.client cl ON cl.id = o.supplier_id
      WHERE o.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY o.created_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(o) || jsonb_build_object(''supplier_name'', cl.name, ''total_ttc'', purchase._total_ttc(o.id))
       FROM purchase.purchase_order o
       JOIN crm.client cl ON cl.id = o.supplier_id
       WHERE o.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
       || ' AND ' || pgv.rsql_to_where(p_filter, 'purchase', 'purchase_order')
       || ' ORDER BY o.created_at DESC';
  END IF;
END;
$function$;
