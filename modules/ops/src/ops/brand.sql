CREATE OR REPLACE FUNCTION ops.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT 'Ops'::text;
$function$;
