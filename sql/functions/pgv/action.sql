CREATE OR REPLACE FUNCTION pgv.action(p_endpoint text, p_label text, p_target text DEFAULT '#app'::text, p_confirm text DEFAULT NULL::text, p_variant text DEFAULT 'primary'::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<button hx-post="' || p_endpoint || '" hx-target="' || p_target || '"'
    || CASE WHEN p_confirm IS NOT NULL THEN ' hx-confirm="' || pgv.esc(p_confirm) || '"' ELSE '' END
    || CASE WHEN p_variant = 'danger' THEN ' class="secondary"'
            WHEN p_variant = 'outline' THEN ' class="outline"'
            ELSE '' END
    || '>' || pgv.esc(p_label) || '</button>';
$function$;
