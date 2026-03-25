CREATE OR REPLACE FUNCTION stock.article_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(a) || jsonb_build_object(
        'supplier_name', c.name,
        'current_stock', stock._current_stock(a.id)
      )
      FROM stock.article a
      LEFT JOIN crm.client c ON c.id = a.supplier_id
      WHERE a.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY a.description;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(a) || jsonb_build_object(
        ''supplier_name'', c.name,
        ''current_stock'', stock._current_stock(a.id)
      )
      FROM stock.article a
      LEFT JOIN crm.client c ON c.id = a.supplier_id
      WHERE a.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
      || ' AND ' || pgv.rsql_to_where(p_filter, 'stock', 'article')
      || ' ORDER BY a.description';
  END IF;
END;
$function$;
