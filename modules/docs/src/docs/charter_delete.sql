CREATE OR REPLACE FUNCTION docs.charter_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_row docs.charter;
BEGIN
  DELETE FROM docs.charter WHERE (slug = p_id OR id = p_id) AND tenant_id = current_setting('app.tenant_id', true) RETURNING * INTO v_row;
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN to_jsonb(v_row);
END;
$function$;
