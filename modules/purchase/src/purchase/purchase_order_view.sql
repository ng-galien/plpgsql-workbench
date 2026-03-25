CREATE OR REPLACE FUNCTION purchase.purchase_order_view()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'purchase://purchase_order',
    'label', 'purchase.entity_purchase_order',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('number', 'supplier_name', 'status', 'total_ttc')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('number', 'supplier_name', 'subject', 'status', 'delivery_date'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'total_ttc', 'label', 'purchase.stat_total_ttc'),
          jsonb_build_object('key', 'line_count', 'label', 'purchase.stat_line_count'),
          jsonb_build_object('key', 'receipt_count', 'label', 'purchase.stat_receipt_count')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'crm://client', 'filter', 'id={supplier_id}', 'label', 'purchase.rel_supplier'),
          jsonb_build_object('entity', 'purchase://supplier_invoice', 'filter', 'order_id={id}', 'label', 'purchase.rel_invoices')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('number', 'supplier_name', 'subject', 'status', 'delivery_date', 'payment_terms', 'notes', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'total_ht', 'label', 'purchase.stat_total_ht'),
          jsonb_build_object('key', 'total_tva', 'label', 'purchase.stat_total_tva'),
          jsonb_build_object('key', 'total_ttc', 'label', 'purchase.stat_total_ttc'),
          jsonb_build_object('key', 'line_count', 'label', 'purchase.stat_line_count'),
          jsonb_build_object('key', 'receipt_count', 'label', 'purchase.stat_receipt_count')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'crm://client', 'filter', 'id={supplier_id}', 'label', 'purchase.rel_supplier'),
          jsonb_build_object('entity', 'purchase://supplier_invoice', 'filter', 'order_id={id}', 'label', 'purchase.rel_invoices')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'purchase.section_order', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'supplier_id', 'label', 'purchase.field_supplier', 'type', 'combobox',
              'source', 'crm://client', 'display', 'name', 'required', true),
            jsonb_build_object('key', 'subject', 'label', 'purchase.field_subject', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'delivery_date', 'label', 'purchase.field_delivery_date', 'type', 'date'),
            jsonb_build_object('key', 'payment_terms', 'label', 'purchase.field_payment_terms', 'type', 'text'),
            jsonb_build_object('key', 'notes', 'label', 'purchase.field_notes', 'type', 'textarea')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'send', jsonb_build_object('label', 'purchase.action_send', 'confirm', 'purchase.confirm_send'),
      'receive', jsonb_build_object('label', 'purchase.action_receive', 'confirm', 'purchase.confirm_receive'),
      'cancel', jsonb_build_object('label', 'purchase.action_cancel', 'variant', 'danger', 'confirm', 'purchase.confirm_cancel'),
      'delete', jsonb_build_object('label', 'purchase.action_delete', 'variant', 'danger', 'confirm', 'purchase.confirm_delete')
    )
  );
END;
$function$;
