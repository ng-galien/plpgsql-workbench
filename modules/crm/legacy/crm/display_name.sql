CREATE OR REPLACE FUNCTION crm.display_name(p_client crm.client)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT CASE
    WHEN p_client.type = 'company' AND p_client.city IS NOT NULL
      THEN p_client.name || ' (' || p_client.city || ')'
    ELSE p_client.name
  END;
$function$;
