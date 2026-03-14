CREATE OR REPLACE FUNCTION document.canvas_clear(p_canvas_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_count int;
BEGIN
  DELETE FROM document.element
  WHERE canvas_id = p_canvas_id
    AND tenant_id = current_setting('app.tenant_id', true);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;
