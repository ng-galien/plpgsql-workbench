CREATE OR REPLACE FUNCTION pgv.badge(p_text text, p_variant text DEFAULT 'default'::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<span class="pgv-badge'
    || CASE WHEN p_variant <> 'default' THEN ' pgv-badge-' || p_variant ELSE '' END
    || '">' || p_text || '</span>';
$function$;
