CREATE OR REPLACE FUNCTION sdui.ui_badge(p_text text, p_variant text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'badge', 'text', p_text) 
    || CASE WHEN p_variant IS NOT NULL THEN jsonb_build_object('variant', p_variant) ELSE '{}'::jsonb END;
$function$;
