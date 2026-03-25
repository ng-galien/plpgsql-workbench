CREATE OR REPLACE FUNCTION hr.statut_variant(p_status text)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT hr.status_variant(p_status);
$function$;
