CREATE OR REPLACE FUNCTION hr.absence_update(p_row hr.leave_request)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE hr.leave_request SET
    leave_type = COALESCE(NULLIF(p_row.leave_type, ''), leave_type),
    start_date = COALESCE(p_row.start_date, start_date),
    end_date = COALESCE(p_row.end_date, end_date),
    day_count = COALESCE(p_row.day_count, day_count),
    reason = COALESCE(p_row.reason, reason),
    status = COALESCE(NULLIF(p_row.status, ''), status)
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
