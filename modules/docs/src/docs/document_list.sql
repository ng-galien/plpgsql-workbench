CREATE OR REPLACE FUNCTION docs.document_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF docs.document
 LANGUAGE plpgsql
 STABLE
 SET "api.expose" TO 'mcp'
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY SELECT * FROM docs.document WHERE tenant_id = current_setting('app.tenant_id', true) ORDER BY updated_at DESC;
  ELSE
    RETURN QUERY EXECUTE 'SELECT * FROM docs.document WHERE tenant_id = ' || quote_literal(current_setting('app.tenant_id', true)) || ' AND ' || pgv.rsql_to_where(p_filter, 'docs', 'document') || ' ORDER BY updated_at DESC';
  END IF;
END;
$function$;
