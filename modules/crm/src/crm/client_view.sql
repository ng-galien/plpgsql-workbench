CREATE OR REPLACE FUNCTION crm.client_view()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'crm://client',
    'label', 'crm.entity_client',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('name', 'type', 'tier')
      ),

      'standard', jsonb_build_object(
        'fields', jsonb_build_array('type', 'email', 'phone', 'city', 'tier'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'quote_count', 'label', 'crm.stat_quotes'),
          jsonb_build_object('key', 'total_revenue', 'label', 'crm.stat_revenue'),
          jsonb_build_object('key', 'pending_amount', 'label', 'crm.stat_pending')
        )
      ),

      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('type', 'email', 'phone', 'address', 'city', 'postal_code', 'tier', 'tags', 'notes', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'quote_count', 'label', 'crm.stat_quotes'),
          jsonb_build_object('key', 'total_revenue', 'label', 'crm.stat_revenue'),
          jsonb_build_object('key', 'pending_amount', 'label', 'crm.stat_pending'),
          jsonb_build_object('key', 'contact_count', 'label', 'crm.col_contacts'),
          jsonb_build_object('key', 'interaction_count', 'label', 'crm.col_interactions')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'quote://devis', 'filter', 'client_id={id}', 'label', 'crm.related_quotes'),
          jsonb_build_object('entity', 'quote://facture', 'filter', 'client_id={id}', 'label', 'crm.related_invoices')
        )
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'crm.section_identity', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'type', 'label', 'crm.field_type', 'type', 'select',
              'options', jsonb_build_array(
                jsonb_build_object('label', 'crm.type_individual', 'value', 'individual'),
                jsonb_build_object('label', 'crm.type_company', 'value', 'company')
              ), 'required', true),
            jsonb_build_object('key', 'name', 'label', 'crm.field_name', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'tier', 'label', 'crm.field_tier', 'type', 'select',
              'options', jsonb_build_array(
                jsonb_build_object('label', 'Standard', 'value', 'standard'),
                jsonb_build_object('label', 'Premium', 'value', 'premium'),
                jsonb_build_object('label', 'VIP', 'value', 'vip')
              ))
          )),
          jsonb_build_object('label', 'crm.section_contact', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'email', 'label', 'crm.field_email', 'type', 'email'),
            jsonb_build_object('key', 'phone', 'label', 'crm.field_phone', 'type', 'tel')
          )),
          jsonb_build_object('label', 'crm.section_address', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'address', 'label', 'crm.field_address', 'type', 'text'),
            jsonb_build_object('key', 'city', 'label', 'crm.field_city', 'type', 'text'),
            jsonb_build_object('key', 'postal_code', 'label', 'crm.field_postal_code', 'type', 'text')
          )),
          jsonb_build_object('label', 'crm.section_notes', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'tags', 'label', 'crm.field_tags', 'type', 'text'),
            jsonb_build_object('key', 'notes', 'label', 'crm.field_notes', 'type', 'textarea')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'archive', jsonb_build_object('label', 'crm.action_archive', 'variant', 'warning', 'confirm', 'crm.confirm_archive'),
      'activate', jsonb_build_object('label', 'crm.action_activate'),
      'delete', jsonb_build_object('label', 'crm.action_delete', 'variant', 'danger', 'confirm', 'crm.confirm_delete_client')
    )
  );
END;
$function$;
