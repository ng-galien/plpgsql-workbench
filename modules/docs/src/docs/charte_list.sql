CREATE OR REPLACE FUNCTION docs.charte_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF docs.charte
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY SELECT * FROM docs.charte WHERE tenant_id = current_setting('app.tenant_id', true) ORDER BY name;
  ELSE
    RETURN QUERY EXECUTE 'SELECT * FROM docs.charte WHERE tenant_id = ' || quote_literal(current_setting('app.tenant_id', true)) || ' AND ' || pgv.rsql_to_where(p_filter, 'docs', 'charte') || ' ORDER BY name';
  END IF;
END;
$function$;
