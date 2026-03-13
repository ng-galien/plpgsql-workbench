CREATE OR REPLACE FUNCTION document.company_info()
 RETURNS document.company
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_row document.company;
BEGIN
  SELECT * INTO v_row
  FROM document.company
  WHERE tenant_id = current_setting('app.tenant_id', true)
  LIMIT 1;
  RETURN v_row;
END;
$function$;
