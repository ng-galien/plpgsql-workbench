CREATE OR REPLACE FUNCTION purchase.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'purchase.brand', 'Achats'),
    ('fr', 'purchase.nav_dashboard', 'Dashboard'),
    ('fr', 'purchase.nav_commandes', 'Commandes'),
    ('fr', 'purchase.nav_factures', 'Factures'),
    ('fr', 'purchase.nav_recap', 'Récap.'),
    ('fr', 'purchase.nav_prix_articles', 'Prix articles'),

    -- Statut badges
    ('fr', 'purchase.status_brouillon', 'Brouillon'),
    ('fr', 'purchase.status_envoyee', 'Envoyée'),
    ('fr', 'purchase.status_partielle', 'Partielle'),
    ('fr', 'purchase.status_recue', 'Reçue'),
    ('fr', 'purchase.status_annulee', 'Annulée'),
    ('fr', 'purchase.status_validee', 'Validée'),
    ('fr', 'purchase.status_payee', 'Payée'),

    -- Workflow steps (commande)
    ('fr', 'purchase.wf_brouillon', 'Brouillon'),
    ('fr', 'purchase.wf_envoyee', 'Envoyée'),
    ('fr', 'purchase.wf_partielle', 'Partielle'),
    ('fr', 'purchase.wf_recue', 'Reçue'),

    -- Workflow steps (facture)
    ('fr', 'purchase.wf_recue_fac', 'Reçue'),
    ('fr', 'purchase.wf_validee', 'Validée'),
    ('fr', 'purchase.wf_payee', 'Payée'),

    -- Stats
    ('fr', 'purchase.stat_commandes_en_cours', 'Commandes en cours'),
    ('fr', 'purchase.stat_a_receptionner', 'À réceptionner'),
    ('fr', 'purchase.stat_factures_impayees', 'Factures impayées'),
    ('fr', 'purchase.stat_achats_mois', 'Achats du mois'),
    ('fr', 'purchase.stat_total_a_payer', 'Total à payer'),
    ('fr', 'purchase.stat_en_retard', 'En retard'),
    ('fr', 'purchase.stat_total_annuel', 'Total annuel HT'),
    ('fr', 'purchase.stat_achats', 'Achats'),
    ('fr', 'purchase.stat_prix_min', 'Prix min'),
    ('fr', 'purchase.stat_prix_max', 'Prix max'),
    ('fr', 'purchase.stat_prix_moyen', 'Prix moyen'),

    -- Table headers
    ('fr', 'purchase.col_numero', 'Numéro'),
    ('fr', 'purchase.col_fournisseur', 'Fournisseur'),
    ('fr', 'purchase.col_objet', 'Objet'),
    ('fr', 'purchase.col_statut', 'Statut'),
    ('fr', 'purchase.col_total_ttc', 'Total TTC'),
    ('fr', 'purchase.col_date', 'Date'),
    ('fr', 'purchase.col_no_fournisseur', 'N° fournisseur'),
    ('fr', 'purchase.col_commande', 'Commande'),
    ('fr', 'purchase.col_montant_ttc', 'Montant TTC'),
    ('fr', 'purchase.col_date_facture', 'Date facture'),
    ('fr', 'purchase.col_echeance', 'Echéance'),
    ('fr', 'purchase.col_commandes', 'Commandes'),
    ('fr', 'purchase.col_total_achats_ht', 'Total achats HT'),
    ('fr', 'purchase.col_derniere_commande', 'Dernière commande'),
    ('fr', 'purchase.col_description', 'Description'),
    ('fr', 'purchase.col_qte', 'Qté'),
    ('fr', 'purchase.col_pu', 'PU'),
    ('fr', 'purchase.col_tva', 'TVA'),
    ('fr', 'purchase.col_total_ht', 'Total HT'),
    ('fr', 'purchase.col_restant', 'Restant'),
    ('fr', 'purchase.col_lignes', 'Lignes'),
    ('fr', 'purchase.col_notes', 'Notes'),
    ('fr', 'purchase.col_designation', 'Désignation'),
    ('fr', 'purchase.col_unite', 'Unité'),
    ('fr', 'purchase.col_pu_ht', 'PU HT'),
    ('fr', 'purchase.col_prix_unitaire', 'Prix unitaire'),
    ('fr', 'purchase.col_quantite', 'Quantité'),
    ('fr', 'purchase.col_total', 'Total'),

    -- Month abbreviations
    ('fr', 'purchase.month_jan', 'Jan'),
    ('fr', 'purchase.month_feb', 'Fév'),
    ('fr', 'purchase.month_mar', 'Mar'),
    ('fr', 'purchase.month_apr', 'Avr'),
    ('fr', 'purchase.month_may', 'Mai'),
    ('fr', 'purchase.month_jun', 'Jun'),
    ('fr', 'purchase.month_jul', 'Jul'),
    ('fr', 'purchase.month_aug', 'Aoû'),
    ('fr', 'purchase.month_sep', 'Sep'),
    ('fr', 'purchase.month_oct', 'Oct'),
    ('fr', 'purchase.month_nov', 'Nov'),
    ('fr', 'purchase.month_dec', 'Déc'),

    -- Tabs
    ('fr', 'purchase.tab_commandes_recentes', 'Commandes récentes'),
    ('fr', 'purchase.tab_factures_fournisseur', 'Factures fournisseur'),
    ('fr', 'purchase.tab_top_fournisseurs', 'Top fournisseurs'),

    -- Section titles
    ('fr', 'purchase.title_lignes', 'Lignes'),
    ('fr', 'purchase.title_receptions', 'Réceptions'),
    ('fr', 'purchase.title_recap', 'Récapitulatif achats'),
    ('fr', 'purchase.title_bon_commande', 'Bon de commande'),
    ('fr', 'purchase.title_historique_prix', 'Historique prix'),
    ('fr', 'purchase.title_nouvelle_commande', 'Nouvelle commande'),
    ('fr', 'purchase.title_modifier_commande', 'Modifier commande'),
    ('fr', 'purchase.title_saisir_facture', 'Saisir une facture fournisseur'),

    -- Card labels
    ('fr', 'purchase.card_commande', 'Commande'),
    ('fr', 'purchase.card_fournisseur', 'Fournisseur'),
    ('fr', 'purchase.card_total_ttc', 'Total TTC'),
    ('fr', 'purchase.card_livraison', 'Livraison'),
    ('fr', 'purchase.card_facture', 'Facture'),
    ('fr', 'purchase.card_montant_ht', 'Montant HT'),
    ('fr', 'purchase.card_montant_ttc', 'Montant TTC'),

    -- Detail labels
    ('fr', 'purchase.label_objet', 'Objet :'),
    ('fr', 'purchase.label_conditions', 'Conditions paiement :'),
    ('fr', 'purchase.label_notes', 'Notes :'),
    ('fr', 'purchase.label_total_ht', 'Total HT :'),
    ('fr', 'purchase.label_tva', 'TVA :'),
    ('fr', 'purchase.label_ttc', 'TTC :'),
    ('fr', 'purchase.label_total_ttc', 'Total TTC :'),
    ('fr', 'purchase.label_date_facture', 'Date facture :'),
    ('fr', 'purchase.label_echeance', 'Echéance :'),
    ('fr', 'purchase.label_rapprochement', 'Rapprochement :'),
    ('fr', 'purchase.label_commande_ttc', 'Commande TTC ='),
    ('fr', 'purchase.label_ecart', 'Ecart ='),
    ('fr', 'purchase.label_date', 'Date :'),
    ('fr', 'purchase.label_livraison_souhaitee', 'Livraison souhaitée :'),
    ('fr', 'purchase.label_paiement', 'Paiement :'),
    ('fr', 'purchase.label_no', 'N° :'),

    -- Form fields
    ('fr', 'purchase.field_fournisseur', 'Fournisseur'),
    ('fr', 'purchase.field_objet', 'Objet'),
    ('fr', 'purchase.field_date_livraison', 'Date livraison prévue'),
    ('fr', 'purchase.field_conditions', 'Conditions paiement'),
    ('fr', 'purchase.field_notes', 'Notes'),
    ('fr', 'purchase.field_description', 'Description'),
    ('fr', 'purchase.field_quantite', 'Quantité'),
    ('fr', 'purchase.field_unite', 'Unité'),
    ('fr', 'purchase.field_prix_unitaire', 'Prix unitaire'),
    ('fr', 'purchase.field_tva', 'TVA %'),
    ('fr', 'purchase.field_article_stock', 'Article stock'),
    ('fr', 'purchase.field_no_fournisseur', 'N° fournisseur'),
    ('fr', 'purchase.field_montant_ht', 'Montant HT'),
    ('fr', 'purchase.field_montant_ttc', 'Montant TTC'),
    ('fr', 'purchase.field_date_facture', 'Date facture'),
    ('fr', 'purchase.field_date_echeance', 'Date échéance'),
    ('fr', 'purchase.field_commande_liee', 'Commande liée'),
    ('fr', 'purchase.field_search_fournisseur', 'Rechercher un fournisseur...'),
    ('fr', 'purchase.field_search_article', 'Rechercher un article...'),
    ('fr', 'purchase.field_placeholder_conditions', 'ex: 30j fin de mois'),
    ('fr', 'purchase.field_placeholder_facture', 'ex: FAC-2026-042'),
    ('fr', 'purchase.field_aucune', '(aucune)'),

    -- Buttons / Actions
    ('fr', 'purchase.btn_nouvelle_commande', 'Nouvelle commande'),
    ('fr', 'purchase.btn_modifier', 'Modifier'),
    ('fr', 'purchase.btn_envoyer', 'Envoyer'),
    ('fr', 'purchase.btn_annuler', 'Annuler'),
    ('fr', 'purchase.btn_receptionner', 'Réceptionner'),
    ('fr', 'purchase.btn_supprimer', 'Supprimer'),
    ('fr', 'purchase.btn_ajouter', 'Ajouter'),
    ('fr', 'purchase.btn_enregistrer', 'Enregistrer'),
    ('fr', 'purchase.btn_valider', 'Valider'),
    ('fr', 'purchase.btn_payer', 'Marquer payée'),
    ('fr', 'purchase.btn_comptabiliser', 'Comptabiliser'),
    ('fr', 'purchase.btn_saisir', 'Saisir'),
    ('fr', 'purchase.btn_retour_commande', 'Retour à la commande'),
    ('fr', 'purchase.btn_retour_commandes', 'Retour commandes'),
    ('fr', 'purchase.btn_voir_fiche', 'Voir fiche article'),
    ('fr', 'purchase.btn_voir_bon', 'Voir le bon de commande'),
    ('fr', 'purchase.btn_ajouter_ligne', 'Ajouter une ligne'),

    -- Confirm dialogs
    ('fr', 'purchase.confirm_envoyer', 'Marquer cette commande comme envoyée ?'),
    ('fr', 'purchase.confirm_annuler', 'Annuler cette commande ?'),
    ('fr', 'purchase.confirm_reception', 'Créer une réception pour cette commande ?'),
    ('fr', 'purchase.confirm_supprimer_ligne', 'Supprimer cette ligne ?'),
    ('fr', 'purchase.confirm_valider_facture', 'Valider cette facture ?'),
    ('fr', 'purchase.confirm_payer', 'Marquer cette facture comme payée ?'),
    ('fr', 'purchase.confirm_comptabiliser', 'Créer l''écriture comptable pour cette facture ?'),

    -- Empty states
    ('fr', 'purchase.empty_no_commande', 'Aucune commande'),
    ('fr', 'purchase.empty_first_commande', 'Créez votre première commande fournisseur.'),
    ('fr', 'purchase.empty_no_facture', 'Aucune facture fournisseur'),
    ('fr', 'purchase.empty_facture_hint', 'Les factures apparaissent ici après saisie.'),
    ('fr', 'purchase.empty_no_ligne', 'Aucune ligne'),
    ('fr', 'purchase.empty_no_achat_article', 'Aucun achat enregistré pour cet article'),
    ('fr', 'purchase.empty_commande_introuvable', 'Commande introuvable'),

    -- Toast messages
    ('fr', 'purchase.toast_commande_updated', 'Commande mise à jour'),
    ('fr', 'purchase.toast_commande_created', 'Commande créée'),
    ('fr', 'purchase.toast_commande_envoyee', 'Commande envoyée'),
    ('fr', 'purchase.toast_commande_annulee', 'Commande annulée'),
    ('fr', 'purchase.toast_ligne_ajoutee', 'Ligne ajoutée'),
    ('fr', 'purchase.toast_ligne_supprimee', 'Ligne supprimée'),
    ('fr', 'purchase.toast_facture_saisie', 'Facture fournisseur saisie'),
    ('fr', 'purchase.toast_facture_validee', 'Facture validée'),
    ('fr', 'purchase.toast_facture_payee', 'Facture marquée payée'),
    ('fr', 'purchase.toast_ecriture_creee', 'Écriture comptable créée'),

    -- Error messages
    ('fr', 'purchase.err_commande_not_found', 'Commande introuvable ou non modifiable'),
    ('fr', 'purchase.err_already_sent', 'Commande introuvable ou déjà envoyée'),
    ('fr', 'purchase.err_cancel_receptions', 'Impossible d''annuler : des réceptions existent'),
    ('fr', 'purchase.err_not_cancellable', 'Commande introuvable ou non annulable'),
    ('fr', 'purchase.err_draft_only', 'Lignes modifiables uniquement sur brouillon'),
    ('fr', 'purchase.err_not_receivable', 'Commande non réceptionnable'),
    ('fr', 'purchase.err_all_received', 'Tout est déjà réceptionné'),
    ('fr', 'purchase.err_facture_not_found', 'Facture introuvable'),
    ('fr', 'purchase.err_facture_already_validated', 'Facture introuvable ou déjà validée'),
    ('fr', 'purchase.err_facture_not_validated', 'Facture introuvable ou non validée'),
    ('fr', 'purchase.err_must_pay_first', 'La facture doit être payée avant comptabilisation'),
    ('fr', 'purchase.err_no_amount', 'Facture sans montant'),
    ('fr', 'purchase.err_already_booked', 'Facture déjà comptabilisée'),
    ('fr', 'purchase.err_no_ledger', 'Module ledger non déployé'),

    -- Badge labels
    ('fr', 'purchase.badge_retard', 'retard'),
    ('fr', 'purchase.badge_14j', '> 14j'),
    ('fr', 'purchase.badge_ecart', 'écart'),
    ('fr', 'purchase.badge_ok', 'OK'),
    ('fr', 'purchase.badge_comptabilisee', 'comptabilisée'),

    -- Entity labels (SDUI)
    ('fr', 'purchase.entity_commande', 'Commande fournisseur'),
    ('fr', 'purchase.entity_facture_fournisseur', 'Facture fournisseur'),

    -- Stats (SDUI)
    ('fr', 'purchase.stat_total_ht', 'Total HT'),
    ('fr', 'purchase.stat_total_tva', 'Total TVA'),
    ('fr', 'purchase.stat_total_ttc', 'Total TTC'),
    ('fr', 'purchase.stat_nb_lignes', 'Lignes'),
    ('fr', 'purchase.stat_nb_receptions', 'Réceptions'),
    ('fr', 'purchase.stat_montant_ht', 'Montant HT'),
    ('fr', 'purchase.stat_montant_ttc', 'Montant TTC'),
    ('fr', 'purchase.stat_commande_ttc', 'Commande TTC'),
    ('fr', 'purchase.stat_ecart', 'Écart'),

    -- Related (SDUI)
    ('fr', 'purchase.rel_fournisseur', 'Fournisseur'),
    ('fr', 'purchase.rel_factures', 'Factures'),
    ('fr', 'purchase.rel_commande', 'Commande'),

    -- Form sections (SDUI)
    ('fr', 'purchase.section_commande', 'Commande'),
    ('fr', 'purchase.section_facture', 'Facture'),

    -- Actions (SDUI/HATEOAS)
    ('fr', 'purchase.action_envoyer', 'Envoyer'),
    ('fr', 'purchase.action_recevoir', 'Réceptionner'),
    ('fr', 'purchase.action_annuler', 'Annuler'),
    ('fr', 'purchase.action_delete', 'Supprimer'),
    ('fr', 'purchase.action_valider', 'Valider'),
    ('fr', 'purchase.action_payer', 'Marquer payée'),
    ('fr', 'purchase.action_comptabiliser', 'Comptabiliser'),
    ('fr', 'purchase.confirm_delete', 'Supprimer cette commande ?'),
    ('fr', 'purchase.confirm_delete_facture', 'Supprimer cette facture ?')

  ON CONFLICT DO NOTHING;
END;
$function$;
