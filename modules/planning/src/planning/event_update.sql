CREATE OR REPLACE FUNCTION planning.event_update(p_row planning.event)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE planning.event SET title = COALESCE(NULLIF(p_row.title, ''), title), type = COALESCE(NULLIF(p_row.type, ''), type), project_id = COALESCE(p_row.project_id, project_id), start_date = COALESCE(p_row.start_date, start_date), end_date = COALESCE(p_row.end_date, end_date), start_time = COALESCE(p_row.start_time, start_time), end_time = COALESCE(p_row.end_time, end_time), location = COALESCE(p_row.location, location), notes = COALESCE(p_row.notes, notes)
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true) RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
