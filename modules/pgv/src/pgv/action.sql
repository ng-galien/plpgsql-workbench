CREATE OR REPLACE FUNCTION pgv.action(p_rpc text, p_label text, p_params jsonb DEFAULT NULL::jsonb, p_confirm text DEFAULT NULL::text, p_variant text DEFAULT 'primary'::text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<button data-rpc="' || p_rpc || '"'
    || CASE WHEN p_params IS NOT NULL THEN ' data-params=''' || p_params::text || '''' ELSE '' END
    || CASE WHEN p_confirm IS NOT NULL THEN ' data-confirm="' || pgv.esc(p_confirm) || '"' ELSE '' END
    || CASE WHEN p_variant = 'danger' THEN ' class="secondary"'
            WHEN p_variant = 'outline' THEN ' class="outline"'
            ELSE '' END
    || '>' || pgv.esc(p_label) || '</button>';
$function$;
