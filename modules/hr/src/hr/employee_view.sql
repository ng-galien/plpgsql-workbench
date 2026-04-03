CREATE OR REPLACE FUNCTION hr.employee_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'hr://employee',
    'icon', '👤',
    'label', 'hr.entity_employee',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('display_name', 'position', 'status')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('display_name', 'employee_code', 'position', 'department', 'hire_date'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'cp_remaining', 'label', 'hr.stat_cp_remaining'),
          jsonb_build_object('key', 'rtt_remaining', 'label', 'hr.stat_rtt_remaining'),
          jsonb_build_object('key', 'hours_30d', 'label', 'hr.stat_hours_30d')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'hr://absence', 'label', 'hr.rel_absences', 'filter', 'employee_id={id}'),
          jsonb_build_object('entity', 'hr://timesheet', 'label', 'hr.rel_timesheets', 'filter', 'employee_id={id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('display_name', 'employee_code', 'email', 'phone', 'birth_date', 'gender', 'nationality', 'position', 'department', 'qualification', 'contract_label', 'hire_date', 'end_date', 'weekly_hours', 'status', 'notes'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'cp_remaining', 'label', 'hr.stat_cp_remaining'),
          jsonb_build_object('key', 'rtt_remaining', 'label', 'hr.stat_rtt_remaining'),
          jsonb_build_object('key', 'hours_30d', 'label', 'hr.stat_hours_30d'),
          jsonb_build_object('key', 'absence_count', 'label', 'hr.stat_absences')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'hr://absence', 'label', 'hr.rel_absences', 'filter', 'employee_id={id}'),
          jsonb_build_object('entity', 'hr://timesheet', 'label', 'hr.rel_timesheets', 'filter', 'employee_id={id}')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'hr.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'last_name', 'type', 'text', 'label', 'hr.field_last_name', 'required', true),
            jsonb_build_object('key', 'first_name', 'type', 'text', 'label', 'hr.field_first_name', 'required', true),
            jsonb_build_object('key', 'email', 'type', 'email', 'label', 'hr.field_email'),
            jsonb_build_object('key', 'phone', 'type', 'tel', 'label', 'hr.field_phone'),
            jsonb_build_object('key', 'birth_date', 'type', 'date', 'label', 'hr.field_birth_date'),
            jsonb_build_object('key', 'gender', 'type', 'select', 'label', 'hr.field_gender', 'options', 'hr.gender_options'),
            jsonb_build_object('key', 'nationality', 'type', 'text', 'label', 'hr.field_nationality')
          )),
          jsonb_build_object('label', 'hr.section_position', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'position', 'type', 'text', 'label', 'hr.field_position'),
            jsonb_build_object('key', 'department', 'type', 'text', 'label', 'hr.field_department'),
            jsonb_build_object('key', 'qualification', 'type', 'text', 'label', 'hr.field_qualification'),
            jsonb_build_object('key', 'weekly_hours', 'type', 'number', 'label', 'hr.field_weekly_hours')
          )),
          jsonb_build_object('label', 'hr.section_contract', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'employee_code', 'type', 'text', 'label', 'hr.field_employee_code'),
            jsonb_build_object('key', 'contract_type', 'type', 'select', 'label', 'hr.field_contract_type', 'options', 'hr.contract_options'),
            jsonb_build_object('key', 'hire_date', 'type', 'date', 'label', 'hr.field_hire_date', 'required', true),
            jsonb_build_object('key', 'end_date', 'type', 'date', 'label', 'hr.field_end_date'),
            jsonb_build_object('key', 'status', 'type', 'select', 'label', 'hr.col_status', 'options', 'hr.status_options')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'deactivate', jsonb_build_object('label', 'hr.action_deactivate', 'icon', '⏸', 'variant', 'muted'),
      'activate', jsonb_build_object('label', 'hr.action_activate', 'icon', '▶', 'variant', 'primary'),
      'delete', jsonb_build_object('label', 'hr.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'hr.confirm_delete_employee')
    )
  );
END;
$function$;
