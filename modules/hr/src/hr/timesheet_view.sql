CREATE OR REPLACE FUNCTION hr.timesheet_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'hr://timesheet',
    'icon', '⏱',
    'label', 'hr.entity_timesheet',
    'readonly', true,

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('employee_name', 'date_travail', 'heures')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('employee_name', 'date_travail', 'heures', 'description'),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'hr://employee', 'label', 'hr.rel_employee', 'filter', 'id={employee_id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('employee_name', 'date_travail', 'heures', 'description', 'created_at'),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'hr://employee', 'label', 'hr.rel_employee', 'filter', 'id={employee_id}')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'hr.section_timesheet', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'employee_id', 'type', 'combobox', 'label', 'hr.field_employee', 'source', 'hr://employee', 'display', 'display_name', 'required', true),
            jsonb_build_object('key', 'date_travail', 'type', 'date', 'label', 'hr.field_date_travail', 'required', true),
            jsonb_build_object('key', 'heures', 'type', 'number', 'label', 'hr.field_heures', 'required', true),
            jsonb_build_object('key', 'description', 'type', 'text', 'label', 'hr.field_description')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'delete', jsonb_build_object('label', 'hr.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'hr.confirm_delete_timesheet')
    )
  );
END;
$function$;
