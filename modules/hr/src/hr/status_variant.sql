CREATE OR REPLACE FUNCTION hr.status_variant(p_status text)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT CASE p_status
    WHEN 'active' THEN 'success'
    WHEN 'inactive' THEN 'muted'
    WHEN 'pending' THEN 'warning'
    WHEN 'approved' THEN 'success'
    WHEN 'rejected' THEN 'danger'
    WHEN 'cancelled' THEN 'muted'
    ELSE 'default'
  END;
$function$;
