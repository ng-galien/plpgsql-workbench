CREATE OR REPLACE FUNCTION docs.charter_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY SELECT to_jsonb(c) FROM docs.charter c WHERE c.tenant_id = current_setting('app.tenant_id', true) ORDER BY c.name;
  ELSE
    RETURN QUERY EXECUTE 'SELECT to_jsonb(c) FROM docs.charter c WHERE c.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true)) || ' AND ' || pgv.rsql_to_where(p_filter, 'docs', 'charter') || ' ORDER BY c.name';
  END IF;
END;
$function$;
