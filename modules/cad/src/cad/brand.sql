CREATE OR REPLACE FUNCTION cad.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT 'CAD 3D'::text;
$function$;
