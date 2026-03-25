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
        'fields', jsonb_build_array('employee_name', 'type_label', 'nb_jours', 'statut')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('employee_name', 'type_label', 'date_debut', 'date_fin', 'nb_jours', 'motif', 'statut'),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'hr://employee', 'label', 'hr.rel_employee', 'filter', 'id={employee_id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('employee_name', 'type_label', 'date_debut', 'date_fin', 'nb_jours', 'motif', 'statut', 'created_at'),
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
            jsonb_build_object('key', 'type_absence', 'type', 'select', 'label', 'hr.field_type_absence', 'options', 'hr.absence_type_options', 'required', true),
            jsonb_build_object('key', 'date_debut', 'type', 'date', 'label', 'hr.field_date_debut', 'required', true),
            jsonb_build_object('key', 'date_fin', 'type', 'date', 'label', 'hr.field_date_fin_absence', 'required', true),
            jsonb_build_object('key', 'nb_jours', 'type', 'number', 'label', 'hr.field_nb_jours', 'required', true),
            jsonb_build_object('key', 'motif', 'type', 'text', 'label', 'hr.field_motif')
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
