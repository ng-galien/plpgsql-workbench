CREATE OR REPLACE FUNCTION planning.event_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'planning://event', 'label', 'planning.entity_event',
    'template', jsonb_build_object(
      'compact', jsonb_build_object('fields', jsonb_build_array('title', 'type', 'start_date', 'end_date')),
      'standard', jsonb_build_object('fields', jsonb_build_array('title', 'type', 'start_date', 'end_date', 'start_time', 'end_time', 'location'), 'stats', jsonb_build_array(jsonb_build_object('key', 'worker_count', 'label', 'planning.stat_workers')), 'related', jsonb_build_array(jsonb_build_object('entity', 'project://project', 'filter', 'id={project_id}', 'label', 'planning.rel_project'))),
      'expanded', jsonb_build_object('fields', jsonb_build_array('title', 'type', 'start_date', 'end_date', 'start_time', 'end_time', 'location', 'notes', 'created_at'), 'stats', jsonb_build_array(jsonb_build_object('key', 'worker_count', 'label', 'planning.stat_workers')), 'related', jsonb_build_array(jsonb_build_object('entity', 'project://project', 'filter', 'id={project_id}', 'label', 'planning.rel_project'), jsonb_build_object('entity', 'planning://worker', 'filter', 'event_id={id}', 'label', 'planning.title_assigned_team'))),
      'form', jsonb_build_object('sections', jsonb_build_array(
        jsonb_build_object('label', 'planning.section_general', 'fields', jsonb_build_array(jsonb_build_object('key', 'title', 'label', 'planning.field_title', 'type', 'text', 'required', true), jsonb_build_object('key', 'type', 'label', 'planning.field_type', 'type', 'select', 'options', jsonb_build_array(jsonb_build_object('label', 'planning.type_job_site', 'value', 'job_site'), jsonb_build_object('label', 'planning.type_delivery', 'value', 'delivery'), jsonb_build_object('label', 'planning.type_meeting', 'value', 'meeting'), jsonb_build_object('label', 'planning.type_leave', 'value', 'leave'), jsonb_build_object('label', 'planning.type_other', 'value', 'other'))))),
        jsonb_build_object('label', 'planning.section_schedule', 'fields', jsonb_build_array(jsonb_build_object('key', 'start_date', 'label', 'planning.field_start_date', 'type', 'date', 'required', true), jsonb_build_object('key', 'end_date', 'label', 'planning.field_end_date', 'type', 'date', 'required', true), jsonb_build_object('key', 'start_time', 'label', 'planning.field_start_time', 'type', 'text'), jsonb_build_object('key', 'end_time', 'label', 'planning.field_end_time', 'type', 'text'))),
        jsonb_build_object('label', 'planning.section_location', 'fields', jsonb_build_array(jsonb_build_object('key', 'location', 'label', 'planning.field_location', 'type', 'text'), jsonb_build_object('key', 'project_id', 'label', 'planning.field_project', 'type', 'combobox', 'source', 'project://project', 'display', 'code'), jsonb_build_object('key', 'notes', 'label', 'planning.field_notes', 'type', 'textarea')))))
    ),
    'actions', jsonb_build_object('delete', jsonb_build_object('label', 'planning.action_delete', 'variant', 'danger', 'confirm', 'planning.confirm_delete_event'))
  );
END;
$function$;
