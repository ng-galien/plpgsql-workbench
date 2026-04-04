CREATE OR REPLACE FUNCTION hr.absence_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'hr://absence',
    'icon', '📅',
    'label', 'hr.entity_absence',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('employee_name', 'type_label', 'day_count', 'status')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('employee_name', 'type_label', 'start_date', 'end_date', 'day_count', 'reason', 'status'),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'hr://employee', 'label', 'hr.rel_employee', 'filter', 'id={employee_id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('employee_name', 'type_label', 'start_date', 'end_date', 'day_count', 'reason', 'status', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'balance_remaining', 'label', 'hr.stat_balance_remaining')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'hr://employee', 'label', 'hr.rel_employee', 'filter', 'id={employee_id}')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'hr.section_absence', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'employee_id', 'type', 'combobox', 'label', 'hr.field_employee', 'source', 'hr://employee', 'display', 'display_name', 'required', true),
            jsonb_build_object('key', 'leave_type', 'type', 'select', 'label', 'hr.field_absence_type', 'options', 'hr.absence_type_options', 'required', true),
            jsonb_build_object('key', 'start_date', 'type', 'date', 'label', 'hr.field_start_date', 'required', true),
            jsonb_build_object('key', 'end_date', 'type', 'date', 'label', 'hr.field_end_date_absence', 'required', true),
            jsonb_build_object('key', 'day_count', 'type', 'number', 'label', 'hr.field_day_count', 'required', true),
            jsonb_build_object('key', 'reason', 'type', 'text', 'label', 'hr.field_reason')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'validate', jsonb_build_object('label', 'hr.action_validate', 'icon', '✓', 'variant', 'primary'),
      'refuse', jsonb_build_object('label', 'hr.action_refuse', 'icon', '×', 'variant', 'danger'),
      'cancel', jsonb_build_object('label', 'hr.action_cancel', 'icon', '⏹', 'variant', 'muted'),
      'delete', jsonb_build_object('label', 'hr.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'hr.confirm_delete_absence')
    )
  );
END;
$function$;
