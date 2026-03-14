CREATE OR REPLACE FUNCTION document.list_brand_guides()
 RETURNS SETOF document.brand_guide
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT * FROM document.brand_guide
  WHERE tenant_id = current_setting('app.tenant_id', true)
  ORDER BY name;
END;
$function$;
