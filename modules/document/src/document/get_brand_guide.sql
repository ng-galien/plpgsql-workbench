CREATE OR REPLACE FUNCTION document.get_brand_guide(p_id uuid)
 RETURNS document.brand_guide
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_row document.brand_guide;
BEGIN
  SELECT * INTO v_row FROM document.brand_guide
  WHERE id = p_id AND tenant_id = current_setting('app.tenant_id', true);
  RETURN v_row;
END;
$function$;
