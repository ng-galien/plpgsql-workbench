CREATE OR REPLACE FUNCTION asset.asset_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(a)
      FROM asset.asset a
      WHERE a.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY a.created_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(a)
       FROM asset.asset a
       WHERE a.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
       || ' AND ' || pgv.rsql_to_where(p_filter, 'asset', 'asset')
       || ' ORDER BY a.created_at DESC';
  END IF;
END;
$function$;
