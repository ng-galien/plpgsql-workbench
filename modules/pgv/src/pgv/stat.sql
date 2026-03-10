CREATE OR REPLACE FUNCTION pgv.stat(p_label text, p_value text, p_detail text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<article class="pgv-stat">'
    || '<small>' || p_label || '</small>'
    || '<p class="pgv-stat-value">' || p_value || '</p>'
    || CASE WHEN p_detail IS NOT NULL THEN '<small>' || p_detail || '</small>' ELSE '' END
    || '</article>';
$function$;
