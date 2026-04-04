CREATE OR REPLACE FUNCTION hr.timesheet_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_deleted jsonb;
BEGIN
  DELETE FROM hr.timesheet
  WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING to_jsonb(timesheet.*) INTO v_deleted;

  RETURN v_deleted;
END;
$function$;
