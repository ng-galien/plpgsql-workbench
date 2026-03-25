CREATE OR REPLACE FUNCTION hr.contrat_label(p_type text)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT hr.contract_label(p_type);
$function$;
