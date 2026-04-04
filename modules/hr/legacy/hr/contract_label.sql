CREATE OR REPLACE FUNCTION hr.contract_label(p_type text)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT CASE p_type
    WHEN 'cdi' THEN 'CDI'
    WHEN 'cdd' THEN 'CDD'
    WHEN 'apprenticeship' THEN 'Alternance'
    WHEN 'internship' THEN 'Stage'
    WHEN 'temp' THEN 'Intérim'
    ELSE p_type
  END;
$function$;
