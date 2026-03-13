CREATE OR REPLACE FUNCTION hr.contrat_label(p_type text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p_type
    WHEN 'cdi' THEN 'CDI'
    WHEN 'cdd' THEN 'CDD'
    WHEN 'alternance' THEN 'Alternance'
    WHEN 'stage' THEN 'Stage'
    WHEN 'interim' THEN 'Intérim'
    ELSE p_type
  END;
$function$;
