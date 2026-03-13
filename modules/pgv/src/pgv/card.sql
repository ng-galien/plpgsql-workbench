CREATE OR REPLACE FUNCTION pgv.card(p_title text, p_body text, p_footer text DEFAULT NULL::text, p_md boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
SELECT '<article>'
    || CASE WHEN p_title IS NOT NULL THEN '<header>' || p_title || '</header>' ELSE '' END
    || CASE WHEN p_md THEN '<md>' || p_body || '</md>' ELSE p_body END
    || CASE WHEN p_footer IS NOT NULL THEN '<footer>' || p_footer || '</footer>' ELSE '' END
    || '</article>';
$function$;
