CREATE OR REPLACE FUNCTION docs.library_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(l) || jsonb_build_object('asset_count', (SELECT count(*) FROM docs.library_asset la WHERE la.library_id = l.id))
      FROM docs.library l WHERE l.tenant_id = current_setting('app.tenant_id', true) ORDER BY l.name;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(l) || jsonb_build_object(''asset_count'', (SELECT count(*) FROM docs.library_asset la WHERE la.library_id = l.id))
       FROM docs.library l WHERE l.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
       || ' AND ' || pgv.rsql_to_where(p_filter, 'docs', 'library') || ' ORDER BY l.name';
  END IF;
END;
$function$;
