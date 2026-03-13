CREATE OR REPLACE FUNCTION hr.statut_variant(p_statut text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p_statut
    WHEN 'actif' THEN 'success'
    WHEN 'inactif' THEN 'default'
    WHEN 'demande' THEN 'warning'
    WHEN 'validee' THEN 'success'
    WHEN 'refusee' THEN 'danger'
    WHEN 'annulee' THEN 'default'
    ELSE 'default'
  END;
$function$;
