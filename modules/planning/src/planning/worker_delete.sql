CREATE OR REPLACE FUNCTION planning.worker_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_row planning.worker;
BEGIN
  DELETE FROM planning.worker WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true) RETURNING * INTO v_row;
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN to_jsonb(v_row);
END;
$function$;
