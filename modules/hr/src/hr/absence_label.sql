CREATE OR REPLACE FUNCTION hr.absence_label(p_type text)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT hr.leave_type_label(p_type);
$function$;
