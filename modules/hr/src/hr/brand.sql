CREATE OR REPLACE FUNCTION hr.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT 'RH';
$function$;
