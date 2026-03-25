CREATE OR REPLACE FUNCTION expense.category_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'expense://category', 'icon', '🏷', 'label', 'expense.entity_category',
    'template', jsonb_build_object(
      'compact', jsonb_build_object('fields', jsonb_build_array('name', 'accounting_code')),
      'standard', jsonb_build_object('fields', jsonb_build_array('name', 'accounting_code')),
      'expanded', jsonb_build_object('fields', jsonb_build_array('name', 'accounting_code', 'created_at')),
      'form', jsonb_build_object('sections', jsonb_build_array(
        jsonb_build_object('label', 'expense.section_info', 'fields', jsonb_build_array(
          jsonb_build_object('key', 'name', 'type', 'text', 'label', 'expense.field_name', 'required', true),
          jsonb_build_object('key', 'accounting_code', 'type', 'text', 'label', 'expense.field_accounting_code')
        ))
      ))
    ),
    'actions', jsonb_build_object(
      'edit', jsonb_build_object('label', 'expense.action_edit', 'icon', '✏', 'variant', 'muted'),
      'delete', jsonb_build_object('label', 'expense.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'expense.confirm_delete_category')
    )
  );
END;
$function$;
