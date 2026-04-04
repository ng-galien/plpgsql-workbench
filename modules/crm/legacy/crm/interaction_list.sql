CREATE OR REPLACE FUNCTION crm.interaction_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(i) || jsonb_build_object('client_name', c.name)
      FROM crm.interaction i
      JOIN crm.client c ON c.id = i.client_id
      WHERE i.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY i.created_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(i) || jsonb_build_object(''client_name'', c.name)
       FROM crm.interaction i
       JOIN crm.client c ON c.id = i.client_id
       WHERE i.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
       || ' AND ' || pgv.rsql_to_where(p_filter, 'crm', 'interaction')
       || ' ORDER BY i.created_at DESC';
  END IF;
END;
$function$;
