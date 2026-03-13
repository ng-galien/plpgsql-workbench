CREATE OR REPLACE FUNCTION document.get_template(p_id uuid)
 RETURNS document.template
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_row document.template;
BEGIN
  SELECT * INTO v_row
  FROM document.template
  WHERE id = p_id
    AND tenant_id = current_setting('app.tenant_id', true);
  RETURN v_row;
END;
$function$;
