CREATE OR REPLACE FUNCTION cad_qa.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT 'CAD QA'::text;
$function$;
