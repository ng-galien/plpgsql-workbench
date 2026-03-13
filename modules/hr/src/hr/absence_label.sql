CREATE OR REPLACE FUNCTION hr.absence_label(p_type text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p_type
    WHEN 'conge_paye' THEN 'Congé payé'
    WHEN 'rtt' THEN 'RTT'
    WHEN 'maladie' THEN 'Maladie'
    WHEN 'sans_solde' THEN 'Sans solde'
    WHEN 'formation' THEN 'Formation'
    WHEN 'autre' THEN 'Autre'
    ELSE p_type
  END;
$function$;
