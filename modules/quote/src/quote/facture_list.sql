CREATE OR REPLACE FUNCTION quote.facture_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(f) || jsonb_build_object('client_name', c.name, 'devis_numero', dv.numero)
      FROM quote.facture f
      JOIN crm.client c ON c.id = f.client_id
      LEFT JOIN quote.devis dv ON dv.id = f.devis_id
      WHERE f.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY f.created_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(f) || jsonb_build_object(''client_name'', c.name, ''devis_numero'', dv.numero)
       FROM quote.facture f
       JOIN crm.client c ON c.id = f.client_id
       LEFT JOIN quote.devis dv ON dv.id = f.devis_id
       WHERE f.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
       || ' AND ' || pgv.rsql_to_where(p_filter, 'quote', 'facture')
       || ' ORDER BY f.created_at DESC';
  END IF;
END;
$function$;
