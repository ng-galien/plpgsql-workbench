CREATE OR REPLACE FUNCTION cad.drawing_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_row jsonb;
BEGIN
  DELETE FROM cad.drawing
  WHERE id = p_id::int
    AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING to_jsonb(drawing.*) INTO v_row;

  RETURN v_row;
END;
$function$;
