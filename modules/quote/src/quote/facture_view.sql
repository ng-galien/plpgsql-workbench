CREATE OR REPLACE FUNCTION quote.facture_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'quote://facture',
    'label', 'quote.entity_facture',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('numero', 'client_name', 'statut')
      ),

      'standard', jsonb_build_object(
        'fields', jsonb_build_array('numero', 'client_name', 'objet', 'statut', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'total_ht', 'label', 'quote.stat_total_ht'),
          jsonb_build_object('key', 'total_tva', 'label', 'quote.stat_total_tva'),
          jsonb_build_object('key', 'total_ttc', 'label', 'quote.stat_total_ttc')
        )
      ),

      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('numero', 'client_name', 'objet', 'statut', 'devis_numero', 'paid_at', 'notes', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'total_ht', 'label', 'quote.stat_total_ht'),
          jsonb_build_object('key', 'total_tva', 'label', 'quote.stat_total_tva'),
          jsonb_build_object('key', 'total_ttc', 'label', 'quote.stat_total_ttc')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'quote://devis', 'filter', 'id={devis_id}', 'label', 'quote.related_devis')
        )
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'quote.section_general', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'client_id', 'type', 'combobox', 'label', 'quote.field_client', 'source', 'crm://client', 'display', 'name', 'required', true),
            jsonb_build_object('key', 'objet', 'type', 'text', 'label', 'quote.field_objet', 'required', true),
            jsonb_build_object('key', 'notes', 'type', 'textarea', 'label', 'quote.field_notes')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'envoyer', jsonb_build_object('label', 'quote.action_envoyer', 'variant', 'primary', 'confirm', 'quote.confirm_envoyer_facture'),
      'payer', jsonb_build_object('label', 'quote.action_payer', 'variant', 'primary', 'confirm', 'quote.confirm_payer_facture'),
      'relancer', jsonb_build_object('label', 'quote.action_relancer', 'variant', 'warning', 'confirm', 'quote.confirm_relancer_facture'),
      'supprimer', jsonb_build_object('label', 'quote.action_supprimer', 'variant', 'danger', 'confirm', 'quote.confirm_supprimer_facture')
    )
  );
END;
$function$;
