CREATE OR REPLACE FUNCTION crm.interaction_view()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'crm://interaction',
    'label', 'crm.entity_interaction',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('subject', 'type', 'client_name')
      ),

      'standard', jsonb_build_object(
        'fields', jsonb_build_array('type', 'subject', 'client_name', 'created_at')
      ),

      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('type', 'subject', 'body', 'client_name', 'created_at')
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'crm.section_interaction', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'client_id', 'label', 'crm.col_client', 'type', 'combobox', 'source', 'crm://client', 'display', 'name', 'required', true),
            jsonb_build_object('key', 'type', 'label', 'crm.field_type', 'type', 'select', 'required', true,
              'options', jsonb_build_array(
                jsonb_build_object('label', 'crm.type_call', 'value', 'call'),
                jsonb_build_object('label', 'crm.type_visit', 'value', 'visit'),
                jsonb_build_object('label', 'crm.type_email', 'value', 'email'),
                jsonb_build_object('label', 'crm.type_note', 'value', 'note')
              )),
            jsonb_build_object('key', 'subject', 'label', 'crm.field_subject', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'body', 'label', 'crm.field_details', 'type', 'textarea')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'delete', jsonb_build_object('label', 'crm.action_delete', 'variant', 'danger', 'confirm', 'crm.confirm_delete_interaction')
    )
  );
END;
$function$;
