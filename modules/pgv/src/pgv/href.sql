CREATE OR REPLACE FUNCTION pgv.href(p_path text)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT coalesce(nullif(current_setting('pgv.route_prefix', true), ''), '') || p_path;
$function$;
