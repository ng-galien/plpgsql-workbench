CREATE OR REPLACE FUNCTION quote.invoice_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(f) || jsonb_build_object('client_name', c.name, 'estimate_number', dv.number)
      FROM quote.invoice f
      JOIN crm.client c ON c.id = f.client_id
      LEFT JOIN quote.estimate dv ON dv.id = f.estimate_id
      WHERE f.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY f.created_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(f) || jsonb_build_object(''client_name'', c.name, ''estimate_number'', dv.number)
       FROM quote.invoice f
       JOIN crm.client c ON c.id = f.client_id
       LEFT JOIN quote.estimate dv ON dv.id = f.estimate_id
       WHERE f.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
       || ' AND ' || pgv.rsql_to_where(p_filter, 'quote', 'invoice')
       || ' ORDER BY f.created_at DESC';
  END IF;
END;
$function$;
