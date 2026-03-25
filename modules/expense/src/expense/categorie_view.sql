CREATE OR REPLACE FUNCTION expense.categorie_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'expense://categorie',
    'icon', '🏷',
    'label', 'expense.entity_categorie',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('nom', 'code_comptable')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('nom', 'code_comptable')
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('nom', 'code_comptable', 'created_at')
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object(
            'label', 'expense.section_info',
            'fields', jsonb_build_array(
              jsonb_build_object('key', 'nom', 'type', 'text', 'label', 'expense.field_nom', 'required', true),
              jsonb_build_object('key', 'code_comptable', 'type', 'text', 'label', 'expense.field_code_comptable')
            )
          )
        )
      )
    ),

    'actions', jsonb_build_object(
      'edit',   jsonb_build_object('label', 'expense.action_edit', 'icon', '✏', 'variant', 'muted'),
      'delete', jsonb_build_object('label', 'expense.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'expense.confirm_delete_categorie')
    )
  );
END;
$function$;
