CREATE OR REPLACE FUNCTION crm.type_label(p_type text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p_type
    WHEN 'individual' THEN 'Particulier'
    WHEN 'company' THEN 'Entreprise'
    WHEN 'call' THEN 'Appel'
    WHEN 'visit' THEN 'Visite'
    WHEN 'email' THEN 'Courriel'
    WHEN 'note' THEN 'Note'
    ELSE p_type
  END;
$function$;
