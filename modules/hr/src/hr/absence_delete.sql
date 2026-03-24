CREATE OR REPLACE FUNCTION hr.absence_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_deleted jsonb;
BEGIN
  DELETE FROM hr.absence
  WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING to_jsonb(absence.*) INTO v_deleted;

  RETURN v_deleted;
END;
$function$;
