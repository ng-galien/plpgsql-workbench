CREATE OR REPLACE FUNCTION expense.expense_report_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'expense://expense_report', 'icon', '📋', 'label', 'expense.entity_expense_report',
    'template', jsonb_build_object(
      'compact', jsonb_build_object('fields', jsonb_build_array('reference', 'author', 'status', 'total_incl_tax')),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'author', 'start_date', 'end_date', 'status', 'comment'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'line_count', 'label', 'expense.stat_line_count'),
          jsonb_build_object('key', 'total_excl_tax', 'label', 'expense.stat_total_excl_tax'),
          jsonb_build_object('key', 'total_incl_tax', 'label', 'expense.stat_total_incl_tax')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'ledger://journal_entry', 'label', 'expense.stat_total', 'filter', 'expense_note_id={id}')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'author', 'start_date', 'end_date', 'status', 'comment', 'created_at', 'updated_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'line_count', 'label', 'expense.stat_line_count'),
          jsonb_build_object('key', 'total_excl_tax', 'label', 'expense.stat_total_excl_tax'),
          jsonb_build_object('key', 'total_incl_tax', 'label', 'expense.stat_total_incl_tax')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'ledger://journal_entry', 'label', 'expense.stat_total', 'filter', 'expense_note_id={id}')
        )
      ),
      'form', jsonb_build_object('sections', jsonb_build_array(
        jsonb_build_object('label', 'expense.section_info', 'fields', jsonb_build_array(
          jsonb_build_object('key', 'author', 'type', 'text', 'label', 'expense.field_author', 'required', true),
          jsonb_build_object('key', 'start_date', 'type', 'date', 'label', 'expense.field_start_date', 'required', true),
          jsonb_build_object('key', 'end_date', 'type', 'date', 'label', 'expense.field_end_date', 'required', true),
          jsonb_build_object('key', 'comment', 'type', 'textarea', 'label', 'expense.field_comment')
        ))
      ))
    ),
    'actions', jsonb_build_object(
      'edit', jsonb_build_object('label', 'expense.action_edit', 'icon', '✏', 'variant', 'muted'),
      'add_line', jsonb_build_object('label', 'expense.action_add_line', 'icon', '+', 'variant', 'primary'),
      'submit', jsonb_build_object('label', 'expense.action_submit', 'icon', '→', 'variant', 'primary', 'confirm', 'expense.confirm_submit'),
      'validate', jsonb_build_object('label', 'expense.action_validate', 'icon', '✓', 'variant', 'primary', 'confirm', 'expense.confirm_validate'),
      'reject', jsonb_build_object('label', 'expense.action_reject', 'icon', '✗', 'variant', 'danger', 'confirm', 'expense.confirm_reject'),
      'reimburse', jsonb_build_object('label', 'expense.action_reimburse', 'icon', '€', 'variant', 'primary', 'confirm', 'expense.confirm_reimburse'),
      'delete', jsonb_build_object('label', 'expense.action_delete', 'icon', '×', 'variant', 'danger', 'confirm', 'expense.confirm_delete')
    )
  );
END;
$function$;
