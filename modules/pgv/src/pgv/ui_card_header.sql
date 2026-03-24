CREATE OR REPLACE FUNCTION pgv.ui_card_header(p_icon text, p_title text, VARIADIC p_badges jsonb[] DEFAULT '{}'::jsonb[])
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('icon', p_icon, 'title', p_title)
    || CASE WHEN array_length(p_badges, 1) > 0
         THEN jsonb_build_object('badges', array_to_json(p_badges)::jsonb)
         ELSE '{}'::jsonb END;
$function$;
