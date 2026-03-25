CREATE OR REPLACE FUNCTION planning.event_create(p_row planning.event)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.type := COALESCE(p_row.type, 'job_site');
  p_row.start_time := COALESCE(p_row.start_time, '08:00');
  p_row.end_time := COALESCE(p_row.end_time, '17:00');
  p_row.location := COALESCE(p_row.location, '');
  p_row.notes := COALESCE(p_row.notes, '');
  p_row.created_at := now();
  INSERT INTO planning.event (tenant_id, title, type, project_id, start_date, end_date, start_time, end_time, location, notes, created_at) VALUES (p_row.tenant_id, p_row.title, p_row.type, p_row.project_id, p_row.start_date, p_row.end_date, p_row.start_time, p_row.end_time, p_row.location, p_row.notes, p_row.created_at) RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
