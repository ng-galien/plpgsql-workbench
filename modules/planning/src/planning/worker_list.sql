CREATE OR REPLACE FUNCTION planning.worker_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(w) || jsonb_build_object(
        'active_event_count', (SELECT count(*)::int FROM planning.assignment a JOIN planning.event e ON e.id = a.event_id WHERE a.worker_id = w.id AND e.end_date >= current_date)
      ) FROM planning.worker w WHERE w.tenant_id = current_setting('app.tenant_id', true) ORDER BY w.active DESC, w.name;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(w) || jsonb_build_object(''active_event_count'', (SELECT count(*)::int FROM planning.assignment a JOIN planning.event e ON e.id = a.event_id WHERE a.worker_id = w.id AND e.end_date >= current_date)) FROM planning.worker w WHERE w.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true)) || ' AND ' || pgv.rsql_to_where(p_filter, 'planning', 'worker') || ' ORDER BY w.active DESC, w.name';
  END IF;
END;
$function$;
