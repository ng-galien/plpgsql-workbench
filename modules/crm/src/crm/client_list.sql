CREATE OR REPLACE FUNCTION crm.client_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(c) || jsonb_build_object(
        'contact_count', (SELECT count(*) FROM crm.contact ct WHERE ct.client_id = c.id),
        'interaction_count', (SELECT count(*) FROM crm.interaction i WHERE i.client_id = c.id)
      )
      FROM crm.client c
      WHERE c.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY c.updated_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(c) || jsonb_build_object(
        ''contact_count'', (SELECT count(*) FROM crm.contact ct WHERE ct.client_id = c.id),
        ''interaction_count'', (SELECT count(*) FROM crm.interaction i WHERE i.client_id = c.id)
      )
      FROM crm.client c
      WHERE c.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
      || ' AND ' || pgv.rsql_to_where(p_filter, 'crm', 'client')
      || ' ORDER BY c.updated_at DESC';
  END IF;
END;
$function$;
