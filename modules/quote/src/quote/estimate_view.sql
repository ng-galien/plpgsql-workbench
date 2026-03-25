CREATE OR REPLACE FUNCTION quote.estimate_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'quote://estimate',
    'label', 'quote.entity_estimate',
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
        'fields', jsonb_build_array('number', 'client_name', 'subject', 'status', 'validity_days', 'notes', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'total_ht', 'label', 'quote.stat_total_ht'),
          jsonb_build_object('key', 'total_tva', 'label', 'quote.stat_total_tva'),
          jsonb_build_object('key', 'total_ttc', 'label', 'quote.stat_total_ttc')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'quote://invoice', 'filter', 'estimate_id={id}', 'label', 'quote.related_invoices')
        )
      ),
      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'quote.section_general', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'client_id', 'type', 'combobox', 'label', 'quote.field_client', 'source', 'crm://client', 'display', 'name', 'required', true),
            jsonb_build_object('key', 'subject', 'type', 'text', 'label', 'quote.field_subject', 'required', true),
            jsonb_build_object('key', 'validity_days', 'type', 'number', 'label', 'quote.field_validity_days'),
            jsonb_build_object('key', 'notes', 'type', 'textarea', 'label', 'quote.field_notes')
          ))
        )
      )
    ),
    'actions', jsonb_build_object(
      'send', jsonb_build_object('label', 'quote.action_send', 'variant', 'primary', 'confirm', 'quote.confirm_send_estimate'),
      'accept', jsonb_build_object('label', 'quote.action_accept', 'variant', 'primary', 'confirm', 'quote.confirm_accept_estimate'),
      'decline', jsonb_build_object('label', 'quote.action_decline', 'variant', 'danger', 'confirm', 'quote.confirm_decline_estimate'),
      'invoice', jsonb_build_object('label', 'quote.action_invoice', 'variant', 'primary', 'confirm', 'quote.confirm_invoice_estimate'),
      'duplicate', jsonb_build_object('label', 'quote.action_duplicate', 'confirm', 'quote.confirm_duplicate_estimate'),
      'delete', jsonb_build_object('label', 'quote.action_delete', 'variant', 'danger', 'confirm', 'quote.confirm_delete_estimate')
    )
  );
END;
$function$;
