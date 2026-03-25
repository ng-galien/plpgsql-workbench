CREATE OR REPLACE FUNCTION cad.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_array(jsonb_build_object('href', '/', 'label', pgv.t('cad.nav_dessins'), 'entity', 'drawing', 'uri', 'cad://drawing'));
$function$;
