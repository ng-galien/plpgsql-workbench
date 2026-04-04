CREATE OR REPLACE FUNCTION pgv.ui_timeline(p_events jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'timeline', 'events', p_events);
$function$;
