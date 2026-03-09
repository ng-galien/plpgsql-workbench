CREATE OR REPLACE FUNCTION pgv.stat(p_label text, p_value text, p_detail text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<article style="text-align:center">'
    || '<small>' || p_label || '</small>'
    || '<p style="font-size:2rem;margin:0.25rem 0;font-weight:600">' || p_value || '</p>'
    || CASE WHEN p_detail IS NOT NULL THEN '<small>' || p_detail || '</small>' ELSE '' END
    || '</article>';
$function$;
