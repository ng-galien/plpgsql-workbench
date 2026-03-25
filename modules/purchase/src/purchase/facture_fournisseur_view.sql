CREATE OR REPLACE FUNCTION purchase.facture_fournisseur_view()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'purchase://facture_fournisseur',
    'label', 'purchase.entity_facture_fournisseur',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('numero_fournisseur', 'fournisseur_name', 'statut', 'montant_ttc')
      ),

      'standard', jsonb_build_object(
        'fields', jsonb_build_array('numero_fournisseur', 'fournisseur_name', 'commande_numero', 'statut', 'montant_ttc', 'date_facture', 'date_echeance'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'montant_ht', 'label', 'purchase.stat_montant_ht'),
          jsonb_build_object('key', 'montant_ttc', 'label', 'purchase.stat_montant_ttc')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'purchase://commande', 'filter', 'id={commande_id}', 'label', 'purchase.rel_commande'),
          jsonb_build_object('entity', 'crm://client', 'filter', 'id={fournisseur_id}', 'label', 'purchase.rel_fournisseur')
        )
      ),

      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('numero_fournisseur', 'fournisseur_name', 'commande_numero', 'statut', 'montant_ht', 'montant_ttc', 'date_facture', 'date_echeance', 'comptabilisee', 'notes', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'montant_ht', 'label', 'purchase.stat_montant_ht'),
          jsonb_build_object('key', 'montant_ttc', 'label', 'purchase.stat_montant_ttc'),
          jsonb_build_object('key', 'commande_ttc', 'label', 'purchase.stat_commande_ttc'),
          jsonb_build_object('key', 'ecart', 'label', 'purchase.stat_ecart', 'variant', 'warning')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'purchase://commande', 'filter', 'id={commande_id}', 'label', 'purchase.rel_commande'),
          jsonb_build_object('entity', 'crm://client', 'filter', 'id={fournisseur_id}', 'label', 'purchase.rel_fournisseur')
        )
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'purchase.section_facture', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'numero_fournisseur', 'label', 'purchase.field_no_fournisseur', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'montant_ht', 'label', 'purchase.field_montant_ht', 'type', 'number', 'required', true),
            jsonb_build_object('key', 'montant_ttc', 'label', 'purchase.field_montant_ttc', 'type', 'number', 'required', true),
            jsonb_build_object('key', 'date_facture', 'label', 'purchase.field_date_facture', 'type', 'date', 'required', true),
            jsonb_build_object('key', 'date_echeance', 'label', 'purchase.field_date_echeance', 'type', 'date'),
            jsonb_build_object('key', 'commande_id', 'label', 'purchase.field_commande_liee', 'type', 'combobox',
              'source', 'purchase://commande', 'display', 'numero'),
            jsonb_build_object('key', 'notes', 'label', 'purchase.field_notes', 'type', 'textarea')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'valider', jsonb_build_object('label', 'purchase.action_valider', 'confirm', 'purchase.confirm_valider_facture'),
      'payer', jsonb_build_object('label', 'purchase.action_payer', 'confirm', 'purchase.confirm_payer'),
      'comptabiliser', jsonb_build_object('label', 'purchase.action_comptabiliser', 'confirm', 'purchase.confirm_comptabiliser'),
      'delete', jsonb_build_object('label', 'purchase.action_delete', 'variant', 'danger', 'confirm', 'purchase.confirm_delete_facture')
    )
  );
END;
$function$;
