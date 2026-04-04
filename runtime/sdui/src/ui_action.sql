CREATE OR REPLACE FUNCTION sdui.ui_action(p_label text, p_verb text, p_uri text, p_variant text DEFAULT NULL::text, p_confirm text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'action', 'label', p_label, 'verb', p_verb, 'uri', p_uri)
    || CASE WHEN p_variant IS NOT NULL THEN jsonb_build_object('variant', p_variant) ELSE '{}'::jsonb END
    || CASE WHEN p_confirm IS NOT NULL THEN jsonb_build_object('confirm', p_confirm) ELSE '{}'::jsonb END;
$function$;
