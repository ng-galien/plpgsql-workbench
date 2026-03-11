CREATE OR REPLACE FUNCTION pgv.alert(p_message text, p_level text DEFAULT 'info'::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<div class="pgv-alert pgv-alert-' || p_level || '" role="alert">'
    || p_message || '</div>';
$function$;
