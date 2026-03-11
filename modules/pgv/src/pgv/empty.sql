CREATE OR REPLACE FUNCTION pgv.empty(p_title text, p_detail text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<div class="pgv-empty"><h4>' || pgv.esc(p_title) || '</h4>'
    || CASE WHEN p_detail IS NOT NULL THEN '<p>' || pgv.esc(p_detail) || '</p>' ELSE '' END
    || '</div>';
$function$;
