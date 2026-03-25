CREATE OR REPLACE FUNCTION ledger.account_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'ledger://account',
    'label', 'ledger.entity_account',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('code', 'label', 'type')
      ),

      'standard', jsonb_build_object(
        'fields', jsonb_build_array('code', 'label', 'type', 'active'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'balance', 'label', 'ledger.col_balance'),
          jsonb_build_object('key', 'line_count', 'label', 'ledger.col_lines')
        )
      ),

      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('code', 'label', 'type', 'parent_code', 'active', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'balance', 'label', 'ledger.col_balance'),
          jsonb_build_object('key', 'line_count', 'label', 'ledger.col_lines')
        )
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'ledger.section_account', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'code', 'label', 'ledger.col_code', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'label', 'label', 'ledger.col_label', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'type', 'label', 'ledger.col_type', 'type', 'select', 'required', true,
              'options', jsonb_build_array(
                jsonb_build_object('label', 'ledger.type_asset', 'value', 'asset'),
                jsonb_build_object('label', 'ledger.type_liability', 'value', 'liability'),
                jsonb_build_object('label', 'ledger.type_equity', 'value', 'equity'),
                jsonb_build_object('label', 'ledger.type_revenue', 'value', 'revenue'),
                jsonb_build_object('label', 'ledger.type_expense', 'value', 'expense')
              )),
            jsonb_build_object('key', 'parent_code', 'label', 'ledger.field_parent_code', 'type', 'text'),
            jsonb_build_object('key', 'active', 'label', 'ledger.col_active', 'type', 'checkbox')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'delete', jsonb_build_object('label', 'ledger.btn_delete', 'variant', 'danger', 'confirm', 'ledger.confirm_delete_account')
    )
  );
END;
$function$;
