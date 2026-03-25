CREATE OR REPLACE FUNCTION planning.event_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(e) || jsonb_build_object('project_code', p.code, 'workers', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', w.id, 'name', w.name, 'color', w.color) ORDER BY w.name) FROM planning.assignment a JOIN planning.worker w ON w.id = a.worker_id WHERE a.event_id = e.id), '[]'::jsonb))
      FROM planning.event e LEFT JOIN project.project p ON p.id = e.project_id
      WHERE e.tenant_id = current_setting('app.tenant_id', true) ORDER BY e.start_date DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(e) || jsonb_build_object(''project_code'', p.code, ''workers'', COALESCE((SELECT jsonb_agg(jsonb_build_object(''id'', w.id, ''name'', w.name, ''color'', w.color) ORDER BY w.name) FROM planning.assignment a JOIN planning.worker w ON w.id = a.worker_id WHERE a.event_id = e.id), ''[]''::jsonb)) FROM planning.event e LEFT JOIN project.project p ON p.id = e.project_id WHERE e.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true)) || ' AND ' || pgv.rsql_to_where(p_filter, 'planning', 'event') || ' ORDER BY e.start_date DESC';
  END IF;
END;
$function$;
