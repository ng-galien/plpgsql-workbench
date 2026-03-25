CREATE OR REPLACE FUNCTION quote.invoice_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'quote://invoice',
    'label', 'quote.entity_invoice',
    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('number', 'client_name', 'status')
      ),
      'standard', jsonb_build_object(
        'fields', jsonb_build_array('number', 'client_name', 'subject', 'status', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'total_ht', 'label', 'quote.stat_total_ht'),
          jsonb_build_object('key', 'total_tva', 'label', 'quote.stat_total_tva'),
          jsonb_build_object('key', 'total_ttc', 'label', 'quote.stat_total_ttc')
        )
      ),
      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('number', 'client_name', 'subject', 'status', 'estimate_number', 'paid_at', 'notes', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'total_ht', 'label', 'quote.stat_total_ht'),
          jsonb_build_object('key', 'total_tva', 'label', 'quote.stat_total_tva'),
          jsonb_build_object('key', 'total_ttc', 'label', 'quote.stat_total_ttc')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'quote://estimate', 'filter', 'id={estimate_id}', 'label', 'quote.related_estimate')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'quote.section_general', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'client_id', 'type', 'combobox', 'label', 'quote.field_client', 'source', 'crm://client', 'display', 'name', 'required', true),
            jsonb_build_object('key', 'subject', 'type', 'text', 'label', 'quote.field_subject', 'required', true),
            jsonb_build_object('key', 'notes', 'type', 'textarea', 'label', 'quote.field_notes')
          ))
        )
      )
    ),
    'actions', jsonb_build_object(
      'send', jsonb_build_object('label', 'quote.action_send', 'variant', 'primary', 'confirm', 'quote.confirm_send_invoice'),
      'pay', jsonb_build_object('label', 'quote.action_pay', 'variant', 'primary', 'confirm', 'quote.confirm_pay_invoice'),
      'remind', jsonb_build_object('label', 'quote.action_remind', 'variant', 'warning', 'confirm', 'quote.confirm_remind_invoice'),
      'delete', jsonb_build_object('label', 'quote.action_delete', 'variant', 'danger', 'confirm', 'quote.confirm_delete_invoice')
    )
  );
END;
$function$;
