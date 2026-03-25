CREATE OR REPLACE FUNCTION purchase.supplier_invoice_view()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'purchase://supplier_invoice',
    'label', 'purchase.entity_supplier_invoice',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('supplier_ref', 'supplier_name', 'status', 'amount_incl_tax')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('supplier_ref', 'supplier_name', 'order_number', 'status', 'amount_incl_tax', 'invoice_date', 'due_date'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'amount_excl_tax', 'label', 'purchase.stat_amount_excl_tax'),
          jsonb_build_object('key', 'amount_incl_tax', 'label', 'purchase.stat_amount_incl_tax')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'purchase://purchase_order', 'filter', 'id={order_id}', 'label', 'purchase.rel_order'),
          jsonb_build_object('entity', 'crm://client', 'filter', 'id={supplier_id}', 'label', 'purchase.rel_supplier')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('supplier_ref', 'supplier_name', 'order_number', 'status', 'amount_excl_tax', 'amount_incl_tax', 'invoice_date', 'due_date', 'posted', 'notes', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'amount_excl_tax', 'label', 'purchase.stat_amount_excl_tax'),
          jsonb_build_object('key', 'amount_incl_tax', 'label', 'purchase.stat_amount_incl_tax'),
          jsonb_build_object('key', 'order_ttc', 'label', 'purchase.stat_order_ttc'),
          jsonb_build_object('key', 'variance', 'label', 'purchase.stat_variance', 'variant', 'warning')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'purchase://purchase_order', 'filter', 'id={order_id}', 'label', 'purchase.rel_order'),
          jsonb_build_object('entity', 'crm://client', 'filter', 'id={supplier_id}', 'label', 'purchase.rel_supplier')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'purchase.section_invoice', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'supplier_ref', 'label', 'purchase.field_supplier_ref', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'amount_excl_tax', 'label', 'purchase.field_amount_excl_tax', 'type', 'number', 'required', true),
            jsonb_build_object('key', 'amount_incl_tax', 'label', 'purchase.field_amount_incl_tax', 'type', 'number', 'required', true),
            jsonb_build_object('key', 'invoice_date', 'label', 'purchase.field_invoice_date', 'type', 'date', 'required', true),
            jsonb_build_object('key', 'due_date', 'label', 'purchase.field_due_date', 'type', 'date'),
            jsonb_build_object('key', 'order_id', 'label', 'purchase.field_linked_order', 'type', 'combobox',
              'source', 'purchase://purchase_order', 'display', 'number'),
            jsonb_build_object('key', 'notes', 'label', 'purchase.field_notes', 'type', 'textarea')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'validate', jsonb_build_object('label', 'purchase.action_validate', 'confirm', 'purchase.confirm_validate'),
      'pay', jsonb_build_object('label', 'purchase.action_pay', 'confirm', 'purchase.confirm_pay'),
      'post', jsonb_build_object('label', 'purchase.action_post', 'confirm', 'purchase.confirm_post'),
      'delete', jsonb_build_object('label', 'purchase.action_delete', 'variant', 'danger', 'confirm', 'purchase.confirm_delete_invoice')
    )
  );
END;
$function$;
