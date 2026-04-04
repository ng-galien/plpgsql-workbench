CREATE OR REPLACE FUNCTION pgv.ui_workflow(p_states text[], p_current text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'workflow', 'states', array_to_json(p_states)::jsonb, 'current', p_current);
$function$;
