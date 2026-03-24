CREATE OR REPLACE FUNCTION quote.devis_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(d) || jsonb_build_object('client_name', c.name)
      FROM quote.devis d
      JOIN crm.client c ON c.id = d.client_id
      WHERE d.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY d.created_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(d) || jsonb_build_object(''client_name'', c.name)
       FROM quote.devis d
       JOIN crm.client c ON c.id = d.client_id
       WHERE d.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
       || ' AND ' || pgv.rsql_to_where(p_filter, 'quote', 'devis')
       || ' ORDER BY d.created_at DESC';
  END IF;
END;
$function$;
