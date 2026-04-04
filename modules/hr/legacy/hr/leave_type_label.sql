CREATE OR REPLACE FUNCTION hr.leave_type_label(p_type text)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT CASE p_type
    WHEN 'paid_leave' THEN 'Congé payé'
    WHEN 'rtt' THEN 'RTT'
    WHEN 'sick' THEN 'Maladie'
    WHEN 'unpaid' THEN 'Sans solde'
    WHEN 'training' THEN 'Formation'
    WHEN 'other' THEN 'Autre'
    ELSE p_type
  END;
$function$;
