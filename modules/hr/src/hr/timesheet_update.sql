CREATE OR REPLACE FUNCTION hr.timesheet_update(p_row hr.timesheet)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE hr.timesheet SET
    date_travail = COALESCE(p_row.date_travail, date_travail),
    heures = COALESCE(p_row.heures, heures),
    description = COALESCE(p_row.description, description)
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
