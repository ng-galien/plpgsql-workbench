CREATE OR REPLACE FUNCTION quote.devis_view()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'quote://devis',
    'label', 'quote.entity_devis',

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
        'fields', jsonb_build_array('numero', 'client_name', 'objet', 'statut', 'validite_jours', 'notes', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'total_ht', 'label', 'quote.stat_total_ht'),
          jsonb_build_object('key', 'total_tva', 'label', 'quote.stat_total_tva'),
          jsonb_build_object('key', 'total_ttc', 'label', 'quote.stat_total_ttc')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'quote://facture', 'filter', 'devis_id={id}', 'label', 'quote.related_factures')
        )
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'quote.section_general', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'client_id', 'type', 'combobox', 'label', 'quote.field_client', 'source', 'crm://client', 'display', 'name', 'required', true),
            jsonb_build_object('key', 'objet', 'type', 'text', 'label', 'quote.field_objet', 'required', true),
            jsonb_build_object('key', 'validite_jours', 'type', 'number', 'label', 'quote.field_validite_jours'),
            jsonb_build_object('key', 'notes', 'type', 'textarea', 'label', 'quote.field_notes')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'envoyer', jsonb_build_object('label', 'quote.action_envoyer', 'variant', 'primary', 'confirm', 'quote.confirm_envoyer_devis'),
      'accepter', jsonb_build_object('label', 'quote.action_accepter', 'variant', 'primary', 'confirm', 'quote.confirm_accepter_devis'),
      'refuser', jsonb_build_object('label', 'quote.action_refuser', 'variant', 'danger', 'confirm', 'quote.confirm_refuser_devis'),
      'facturer', jsonb_build_object('label', 'quote.action_facturer', 'variant', 'primary', 'confirm', 'quote.confirm_facturer_devis'),
      'dupliquer', jsonb_build_object('label', 'quote.action_dupliquer', 'confirm', 'quote.confirm_dupliquer_devis'),
      'supprimer', jsonb_build_object('label', 'quote.action_supprimer', 'variant', 'danger', 'confirm', 'quote.confirm_supprimer_devis')
    )
  );
END;
$function$;
