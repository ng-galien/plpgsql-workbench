CREATE OR REPLACE FUNCTION crm.brand()
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT 'CRM';
$function$;
