CREATE OR REPLACE FUNCTION docs.document_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(d) || jsonb_build_object('charter_name', c.name, 'charter_slug', c.slug, 'charter_color', c.color_accent)
      FROM docs.document d
      LEFT JOIN docs.charter c ON c.id = d.charter_id
      WHERE d.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY d.updated_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(d) || jsonb_build_object(''charter_name'', c.name, ''charter_slug'', c.slug, ''charter_color'', c.color_accent)
       FROM docs.document d
       LEFT JOIN docs.charter c ON c.id = d.charter_id
       WHERE d.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
       || ' AND ' || pgv.rsql_to_where(p_filter, 'docs', 'document')
       || ' ORDER BY d.updated_at DESC';
  END IF;
END;
$function$;
