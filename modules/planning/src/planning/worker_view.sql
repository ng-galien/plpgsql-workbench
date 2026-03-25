CREATE OR REPLACE FUNCTION planning.worker_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'planning://worker', 'label', 'planning.entity_worker',
    'template', jsonb_build_object(
      'compact', jsonb_build_object('fields', jsonb_build_array('name', 'role', 'active')),
      'standard', jsonb_build_object('fields', jsonb_build_array('name', 'role', 'phone', 'color'), 'stats', jsonb_build_array(jsonb_build_object('key', 'active_event_count', 'label', 'planning.stat_active_events'))),
      'expanded', jsonb_build_object('fields', jsonb_build_array('name', 'role', 'phone', 'color', 'active', 'created_at'), 'stats', jsonb_build_array(jsonb_build_object('key', 'active_event_count', 'label', 'planning.stat_active_events')), 'related', jsonb_build_array(jsonb_build_object('entity', 'planning://event', 'filter', 'worker_id={id}', 'label', 'planning.title_upcoming_events'))),
      'form', jsonb_build_object('sections', jsonb_build_array(jsonb_build_object('label', 'planning.section_identity', 'fields', jsonb_build_array(jsonb_build_object('key', 'name', 'label', 'planning.field_name', 'type', 'text', 'required', true), jsonb_build_object('key', 'role', 'label', 'planning.field_role', 'type', 'text'), jsonb_build_object('key', 'phone', 'label', 'planning.field_phone', 'type', 'tel'), jsonb_build_object('key', 'color', 'label', 'planning.field_color', 'type', 'text'), jsonb_build_object('key', 'active', 'label', 'planning.field_active', 'type', 'checkbox')))))
    ),
    'actions', jsonb_build_object(
      'deactivate', jsonb_build_object('label', 'planning.action_deactivate', 'variant', 'warning', 'confirm', 'planning.confirm_deactivate'),
      'activate', jsonb_build_object('label', 'planning.action_activate'),
      'delete', jsonb_build_object('label', 'planning.action_delete', 'variant', 'danger', 'confirm', 'planning.confirm_delete_worker')
    )
  );
END;
$function$;
