CREATE OR REPLACE FUNCTION pgv.ui_card(p_entity_uri text, p_level text, p_header jsonb, p_body jsonb DEFAULT NULL::jsonb, p_related jsonb DEFAULT NULL::jsonb, p_actions jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object(
    'type', 'card',
    'entity_uri', p_entity_uri,
    'level', p_level,
    'header', p_header
  )
  || CASE WHEN p_body IS NOT NULL THEN jsonb_build_object('body', p_body) ELSE '{}'::jsonb END
  || CASE WHEN p_related IS NOT NULL THEN jsonb_build_object('related', p_related) ELSE '{}'::jsonb END
  || CASE WHEN p_actions IS NOT NULL THEN jsonb_build_object('actions', p_actions) ELSE '{}'::jsonb END;
$function$;
