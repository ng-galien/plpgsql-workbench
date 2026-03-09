CREATE OR REPLACE FUNCTION pgv.card(p_title text, p_body text, p_footer text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<article>'
    || CASE WHEN p_title IS NOT NULL THEN '<header>' || p_title || '</header>' ELSE '' END
    || p_body
    || CASE WHEN p_footer IS NOT NULL THEN '<footer>' || p_footer || '</footer>' ELSE '' END
    || '</article>';
$function$;
