CREATE OR REPLACE FUNCTION project.brand()
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT 'Chantiers';
$function$;
