CREATE OR REPLACE FUNCTION shop.pgv_status(p_status text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT shop.pgv_badge(p_status,
    CASE p_status
      WHEN 'confirmed' THEN 'success'
      WHEN 'shipped'   THEN 'info'
      WHEN 'pending'   THEN 'warning'
      WHEN 'cancelled' THEN 'danger'
      ELSE 'default'
    END);
$function$;
