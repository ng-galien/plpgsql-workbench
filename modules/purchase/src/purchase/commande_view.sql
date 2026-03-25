CREATE OR REPLACE FUNCTION purchase.commande_view()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'uri', 'purchase://commande',
    'label', 'purchase.entity_commande',

    'template', jsonb_build_object(
      'compact', jsonb_build_object(
        'fields', jsonb_build_array('numero', 'fournisseur_name', 'statut', 'total_ttc')
      ),

      'standard', jsonb_build_object(
        'fields', jsonb_build_array('numero', 'fournisseur_name', 'objet', 'statut', 'date_livraison'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'total_ttc', 'label', 'purchase.stat_total_ttc'),
          jsonb_build_object('key', 'nb_lignes', 'label', 'purchase.stat_nb_lignes'),
          jsonb_build_object('key', 'nb_receptions', 'label', 'purchase.stat_nb_receptions')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'crm://client', 'filter', 'id={fournisseur_id}', 'label', 'purchase.rel_fournisseur'),
          jsonb_build_object('entity', 'purchase://facture_fournisseur', 'filter', 'commande_id={id}', 'label', 'purchase.rel_factures')
        )
      ),

      'expanded', jsonb_build_object(
        'fields', jsonb_build_array('numero', 'fournisseur_name', 'objet', 'statut', 'date_livraison', 'conditions_paiement', 'notes', 'created_at'),
        'stats', jsonb_build_array(
          jsonb_build_object('key', 'total_ht', 'label', 'purchase.stat_total_ht'),
          jsonb_build_object('key', 'total_tva', 'label', 'purchase.stat_total_tva'),
          jsonb_build_object('key', 'total_ttc', 'label', 'purchase.stat_total_ttc'),
          jsonb_build_object('key', 'nb_lignes', 'label', 'purchase.stat_nb_lignes'),
          jsonb_build_object('key', 'nb_receptions', 'label', 'purchase.stat_nb_receptions')
        ),
        'related', jsonb_build_array(
          jsonb_build_object('entity', 'crm://client', 'filter', 'id={fournisseur_id}', 'label', 'purchase.rel_fournisseur'),
          jsonb_build_object('entity', 'purchase://facture_fournisseur', 'filter', 'commande_id={id}', 'label', 'purchase.rel_factures')
        )
      ),

      'form', jsonb_build_object(
        'sections', jsonb_build_array(
          jsonb_build_object('label', 'purchase.section_commande', 'fields', jsonb_build_array(
            jsonb_build_object('key', 'fournisseur_id', 'label', 'purchase.field_fournisseur', 'type', 'combobox',
              'source', 'crm://client', 'display', 'name', 'required', true),
            jsonb_build_object('key', 'objet', 'label', 'purchase.field_objet', 'type', 'text', 'required', true),
            jsonb_build_object('key', 'date_livraison', 'label', 'purchase.field_date_livraison', 'type', 'date'),
            jsonb_build_object('key', 'conditions_paiement', 'label', 'purchase.field_conditions', 'type', 'text'),
            jsonb_build_object('key', 'notes', 'label', 'purchase.field_notes', 'type', 'textarea')
          ))
        )
      )
    ),

    'actions', jsonb_build_object(
      'envoyer', jsonb_build_object('label', 'purchase.action_envoyer', 'confirm', 'purchase.confirm_envoyer'),
      'recevoir', jsonb_build_object('label', 'purchase.action_recevoir', 'confirm', 'purchase.confirm_reception'),
      'annuler', jsonb_build_object('label', 'purchase.action_annuler', 'variant', 'danger', 'confirm', 'purchase.confirm_annuler'),
      'delete', jsonb_build_object('label', 'purchase.action_delete', 'variant', 'danger', 'confirm', 'purchase.confirm_delete')
    )
  );
END;
$function$;
