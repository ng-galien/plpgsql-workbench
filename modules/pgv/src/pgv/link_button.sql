CREATE OR REPLACE FUNCTION pgv.link_button(p_href text, p_label text, p_variant text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
SELECT '<a href="' || pgv.esc(p_href) || '" role="button" class="pgv-link-button'
    || CASE WHEN p_variant = 'outline' THEN ' outline'
            WHEN p_variant = 'secondary' THEN ' secondary'
            WHEN p_variant = 'contrast' THEN ' contrast'
            ELSE '' END
    || '">' || pgv.esc(p_label) || '</a>';
$function$;
