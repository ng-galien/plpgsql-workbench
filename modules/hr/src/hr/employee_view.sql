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
        'fields', jsonb_build_array('display_name', 'poste', 'statut')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('display_name', 'matricule', 'poste', 'departement', 'date_embauche'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'cp_remaining', 'label', 'hr.stat_cp_remaining'),
          jsonb_build_object('key', 'rtt_remaining', 'label', 'hr.stat_rtt_remaining'),
          jsonb_build_object('key', 'heures_30j', 'label', 'hr.stat_heures_30j')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'hr://absence', 'label', 'hr.rel_absences', 'filter', 'employee_id={id}'),
          jsonb_build_object('entity', 'hr://timesheet', 'label', 'hr.rel_timesheets', 'filter', 'employee_id={id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('display_name', 'matricule', 'email', 'phone', 'date_naissance', 'sexe', 'nationalite', 'poste', 'departement', 'qualification', 'contrat_label', 'date_embauche', 'date_fin', 'heures_hebdo', 'statut', 'notes'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'cp_remaining', 'label', 'hr.stat_cp_remaining'),
          jsonb_build_object('key', 'rtt_remaining', 'label', 'hr.stat_rtt_remaining'),
          jsonb_build_object('key', 'heures_30j', 'label', 'hr.stat_heures_30j'),
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
            jsonb_build_object('key', 'nom', 'type', 'text', 'label', 'hr.field_nom', 'required', true),
            jsonb_build_object('key', 'prenom', 'type', 'text', 'label', 'hr.field_prenom', 'required', true),
            jsonb_build_object('key', 'email', 'type', 'email', 'label', 'hr.field_email'),
            jsonb_build_object('key', 'phone', 'type', 'tel', 'label', 'hr.field_phone'),
            jsonb_build_object('key', 'date_naissance', 'type', 'date', 'label', 'hr.field_date_naissance'),
            jsonb_build_object('key', 'sexe', 'type', 'select', 'label', 'hr.field_sexe', 'options', 'hr.sexe_options'),
            jsonb_build_object('key', 'nationalite', 'type', 'text', 'label', 'hr.field_nationalite')
          )),
          jsonb_build_object('label', 'hr.section_position', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'poste', 'type', 'text', 'label', 'hr.field_poste'),
            jsonb_build_object('key', 'departement', 'type', 'text', 'label', 'hr.field_departement'),
            jsonb_build_object('key', 'qualification', 'type', 'text', 'label', 'hr.field_qualification'),
            jsonb_build_object('key', 'heures_hebdo', 'type', 'number', 'label', 'hr.field_heures_hebdo')
          )),
          jsonb_build_object('label', 'hr.section_contract', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'matricule', 'type', 'text', 'label', 'hr.field_matricule'),
            jsonb_build_object('key', 'type_contrat', 'type', 'select', 'label', 'hr.field_type_contrat', 'options', 'hr.contrat_options'),
            jsonb_build_object('key', 'date_embauche', 'type', 'date', 'label', 'hr.field_date_embauche', 'required', true),
            jsonb_build_object('key', 'date_fin', 'type', 'date', 'label', 'hr.field_date_fin'),
            jsonb_build_object('key', 'statut', 'type', 'select', 'label', 'hr.col_statut', 'options', 'hr.statut_options')
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
