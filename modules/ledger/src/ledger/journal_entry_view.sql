CREATE OR REPLACE FUNCTION ledger.journal_entry_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'ledger://journal_entry',
    'label', 'ledger.entity_journal_entry',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'entry_date', 'status')
      ),

      'standard', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'entry_date', 'description', 'total_debit', 'total_credit'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'line_count', 'label', 'ledger.col_lines'),
          jsonb_build_object('key', 'total_debit', 'label', 'ledger.col_debit'),
          jsonb_build_object('key', 'total_credit', 'label', 'ledger.col_credit')
        )
      ),

      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('reference', 'entry_date', 'description', 'total_debit', 'total_credit', 'posted', 'posted_at', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'line_count', 'label', 'ledger.col_lines'),
          jsonb_build_object('key', 'total_debit', 'label', 'ledger.col_debit'),
          jsonb_build_object('key', 'total_credit', 'label', 'ledger.col_credit')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'quote://facture', 'filter', 'id={facture_id}', 'label', 'ledger.related_facture'),
          jsonb_build_object('entity', 'expense://note', 'filter', 'id={expense_note_id}', 'label', 'ledger.related_expense_note')
        )
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'ledger.section_entry', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'entry_date', 'label', 'ledger.field_date', 'type', 'date', 'required', true),
            jsonb_build_object('key', 'reference', 'label', 'ledger.field_reference', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'description', 'label', 'ledger.field_description', 'type', 'text', 'required', true)
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'post', jsonb_build_object('label', 'ledger.btn_post', 'variant', 'primary', 'confirm', 'ledger.confirm_post_entry'),
      'delete', jsonb_build_object('label', 'ledger.btn_delete', 'variant', 'danger', 'confirm', 'ledger.confirm_delete_draft')
    )
  );
END;
$function$;
