CREATE OR REPLACE FUNCTION project.project_view()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_object(
    'uri', 'project://project', 'icon', '◎', 'label', 'project.entity_project',
    'template', jsonb_build_object(
      'compact', jsonb_build_object('fields', jsonb_build_array('code', 'subject', 'status')),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('code', 'subject', 'address', 'start_date', 'due_date'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'progress', 'label', 'project.stat_progress'),
          jsonb_build_object('key', 'total_hours', 'label', 'project.stat_hours'),
          jsonb_build_object('key', 'milestone_count', 'label', 'project.stat_milestones')),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'crm://client', 'label', 'project.rel_client', 'filter', 'id={client_id}'),
          jsonb_build_object('entity', 'quote://estimate', 'label', 'project.rel_estimate', 'filter', 'id={estimate_id}'))),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('code', 'subject', 'address', 'start_date', 'due_date', 'end_date', 'notes', 'created_at', 'updated_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'progress', 'label', 'project.stat_progress'),
          jsonb_build_object('key', 'total_hours', 'label', 'project.stat_hours'),
          jsonb_build_object('key', 'milestone_count', 'label', 'project.stat_milestones')),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'crm://client', 'label', 'project.rel_client', 'filter', 'id={client_id}'),
          jsonb_build_object('entity', 'quote://estimate', 'label', 'project.rel_estimate', 'filter', 'id={estimate_id}'),
          jsonb_build_object('entity', 'planning://event', 'label', 'project.rel_planning', 'filter', 'project_id={id}'))),
      'form', jsonb_build_object('sections', jsonb_build_array(
        jsonb_build_object('label', 'project.section_identity', 'fields', jsonb_build_array(
          jsonb_build_object('key', 'client_id', 'type', 'combobox', 'label', 'project.field_client', 'required', true, 'source', 'crm://client', 'display', 'name'),
          jsonb_build_object('key', 'estimate_id', 'type', 'combobox', 'label', 'project.field_estimate', 'source', 'quote://estimate', 'display', 'numero'),
          jsonb_build_object('key', 'subject', 'type', 'text', 'label', 'project.field_subject', 'required', true),
          jsonb_build_object('key', 'address', 'type', 'text', 'label', 'project.field_address'))),
        jsonb_build_object('label', 'project.section_dates', 'fields', jsonb_build_array(
          jsonb_build_object('key', 'start_date', 'type', 'date', 'label', 'project.field_start_date'),
          jsonb_build_object('key', 'due_date', 'type', 'date', 'label', 'project.field_due_date'))),
        jsonb_build_object('label', 'project.section_details', 'fields', jsonb_build_array(
          jsonb_build_object('key', 'notes', 'type', 'textarea', 'label', 'project.field_notes')))))),
    'actions', jsonb_build_object(
      'start', jsonb_build_object('label', 'project.action_start', 'icon', '▶', 'variant', 'primary', 'confirm', 'project.confirm_start'),
      'review', jsonb_build_object('label', 'project.action_review', 'icon', '✓', 'variant', 'primary', 'confirm', 'project.confirm_review'),
      'close', jsonb_build_object('label', 'project.action_close', 'icon', '■', 'variant', 'primary', 'confirm', 'project.confirm_close'),
      'edit', jsonb_build_object('label', 'project.action_edit', 'icon', '✎', 'variant', 'muted'),
      'delete', jsonb_build_object('label', 'project.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'project.confirm_delete')));
$function$;
