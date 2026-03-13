CREATE OR REPLACE FUNCTION quote.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'quote.brand', 'Facturation'),
    ('fr', 'quote.nav_dashboard', 'Dashboard'),
    ('fr', 'quote.nav_devis', 'Devis'),
    ('fr', 'quote.nav_factures', 'Factures'),

    -- Statuses
    ('fr', 'quote.status_brouillon', 'Brouillon'),
    ('fr', 'quote.status_envoye', 'Envoyé'),
    ('fr', 'quote.status_envoyee', 'Envoyée'),
    ('fr', 'quote.status_accepte', 'Accepté'),
    ('fr', 'quote.status_payee', 'Payée'),
    ('fr', 'quote.status_refuse', 'Refusé'),
    ('fr', 'quote.status_relance', 'Relance'),

    -- Column headers
    ('fr', 'quote.col_numero', 'Numéro'),
    ('fr', 'quote.col_client', 'Client'),
    ('fr', 'quote.col_objet', 'Objet'),
    ('fr', 'quote.col_statut', 'Statut'),
    ('fr', 'quote.col_total_ttc', 'Total TTC'),
    ('fr', 'quote.col_date', 'Date'),
    ('fr', 'quote.col_description', 'Description'),
    ('fr', 'quote.col_quantite', 'Qté'),
    ('fr', 'quote.col_unite', 'Unité'),
    ('fr', 'quote.col_pu_ht', 'PU HT'),
    ('fr', 'quote.col_tva', 'TVA'),
    ('fr', 'quote.col_montant_ht', 'Montant HT'),

    -- Detail field labels
    ('fr', 'quote.field_numero', 'Numéro'),
    ('fr', 'quote.field_client', 'Client'),
    ('fr', 'quote.field_objet', 'Objet'),
    ('fr', 'quote.field_statut', 'Statut'),
    ('fr', 'quote.field_validite', 'Validité'),
    ('fr', 'quote.field_date', 'Date'),
    ('fr', 'quote.field_total_ht', 'Total HT'),
    ('fr', 'quote.field_total_tva', 'Total TVA'),
    ('fr', 'quote.field_total_ttc', 'Total TTC'),
    ('fr', 'quote.field_devis', 'Devis'),
    ('fr', 'quote.field_paid_at', 'Payée le'),
    ('fr', 'quote.field_notes', 'Notes'),
    ('fr', 'quote.field_jours', 'jours'),
    ('fr', 'quote.field_facture_directe', 'Facture directe'),

    -- Form labels
    ('fr', 'quote.field_select_placeholder', '— Choisir —'),
    ('fr', 'quote.field_validite_jours', 'Validité (jours)'),
    ('fr', 'quote.field_description_placeholder', 'Renseignée depuis l''article si sélectionné'),
    ('fr', 'quote.field_quantite', 'Quantité'),
    ('fr', 'quote.field_prix_unitaire', 'Prix unitaire HT'),
    ('fr', 'quote.field_article', 'Article (catalogue)'),
    ('fr', 'quote.field_article_placeholder', 'Chercher un article...'),

    -- Units
    ('fr', 'quote.unit_u', 'Unité'),
    ('fr', 'quote.unit_h', 'Heure'),
    ('fr', 'quote.unit_m', 'Mètre'),
    ('fr', 'quote.unit_m2', 'm²'),
    ('fr', 'quote.unit_m3', 'm³'),
    ('fr', 'quote.unit_forfait', 'Forfait'),

    -- Stats (index page)
    ('fr', 'quote.stat_devis_en_cours', 'Devis en cours'),
    ('fr', 'quote.stat_factures_impayees', 'Factures impayées'),
    ('fr', 'quote.stat_ca_mois', 'CA du mois'),
    ('fr', 'quote.stat_taux_acceptation', 'Taux acceptation'),

    -- Tab titles
    ('fr', 'quote.tab_devis_recents', 'Devis récents'),
    ('fr', 'quote.tab_factures_recentes', 'Factures récentes'),

    -- Buttons / Actions
    ('fr', 'quote.btn_nouveau_devis', 'Nouveau devis'),
    ('fr', 'quote.btn_nouvelle_facture', 'Nouvelle facture'),
    ('fr', 'quote.btn_modifier', 'Modifier'),
    ('fr', 'quote.btn_envoyer', 'Envoyer'),
    ('fr', 'quote.btn_supprimer', 'Supprimer'),
    ('fr', 'quote.btn_accepter', 'Accepter'),
    ('fr', 'quote.btn_refuser', 'Refuser'),
    ('fr', 'quote.btn_creer_facture', 'Créer la facture'),
    ('fr', 'quote.btn_dupliquer', 'Dupliquer'),
    ('fr', 'quote.btn_marquer_payee', 'Marquer payée'),
    ('fr', 'quote.btn_relancer', 'Relancer'),
    ('fr', 'quote.btn_ajouter', 'Ajouter'),
    ('fr', 'quote.btn_suppr_ligne', 'Suppr.'),
    ('fr', 'quote.btn_creer_devis', 'Créer le devis'),
    ('fr', 'quote.btn_creer_la_facture', 'Créer la facture'),
    ('fr', 'quote.btn_mettre_a_jour', 'Mettre à jour'),

    -- Page / Section titles
    ('fr', 'quote.title_devis', 'Devis'),
    ('fr', 'quote.title_factures', 'Factures'),
    ('fr', 'quote.title_modifier', 'Modifier'),
    ('fr', 'quote.title_nouveau_devis', 'Nouveau devis'),
    ('fr', 'quote.title_nouvelle_facture', 'Nouvelle facture'),
    ('fr', 'quote.title_ajouter_ligne', 'Ajouter une ligne'),
    ('fr', 'quote.title_mentions', 'Mentions légales'),

    -- Confirm dialogs
    ('fr', 'quote.confirm_envoyer_devis', 'Marquer ce devis comme envoyé ?'),
    ('fr', 'quote.confirm_supprimer_devis', 'Supprimer ce brouillon ?'),
    ('fr', 'quote.confirm_accepter_devis', 'Marquer ce devis comme accepté ?'),
    ('fr', 'quote.confirm_refuser_devis', 'Marquer ce devis comme refusé ?'),
    ('fr', 'quote.confirm_facturer_devis', 'Créer une facture depuis ce devis ?'),
    ('fr', 'quote.confirm_dupliquer_devis', 'Dupliquer ce devis en brouillon ?'),
    ('fr', 'quote.confirm_envoyer_facture', 'Marquer cette facture comme envoyée ?'),
    ('fr', 'quote.confirm_supprimer_facture', 'Supprimer ce brouillon ?'),
    ('fr', 'quote.confirm_payer_facture', 'Marquer cette facture comme payée ?'),
    ('fr', 'quote.confirm_relancer_facture', 'Marquer cette facture en relance ?'),
    ('fr', 'quote.confirm_supprimer_ligne', 'Supprimer cette ligne ?'),

    -- Empty states
    ('fr', 'quote.empty_no_devis', 'Aucun devis'),
    ('fr', 'quote.empty_first_devis', 'Créez votre premier devis pour commencer.'),
    ('fr', 'quote.empty_no_facture', 'Aucune facture'),
    ('fr', 'quote.empty_factures_appear', 'Les factures apparaîtront ici.'),
    ('fr', 'quote.empty_no_ligne', 'Aucune ligne'),
    ('fr', 'quote.empty_add_lignes', 'Ajoutez des lignes à ce devis.'),
    ('fr', 'quote.empty_not_found_devis', 'Devis introuvable'),
    ('fr', 'quote.empty_not_found_facture', 'Facture introuvable'),
    ('fr', 'quote.empty_modification_impossible', 'Modification impossible'),
    ('fr', 'quote.empty_brouillons_only', 'Seuls les brouillons sont modifiables.'),

    -- Error messages
    ('fr', 'quote.err_brouillon_only', 'Seuls les brouillons sont modifiables'),
    ('fr', 'quote.err_draft_delete_only', 'Seuls les brouillons peuvent être supprimés'),
    ('fr', 'quote.err_not_found_devis', 'Devis introuvable'),
    ('fr', 'quote.err_not_found_facture', 'Facture introuvable'),
    ('fr', 'quote.err_not_found_ligne', 'Ligne introuvable'),
    ('fr', 'quote.err_accepted_only', 'Seuls les devis acceptés peuvent être facturés'),
    ('fr', 'quote.err_draft_lines_only', 'Lignes modifiables uniquement sur un brouillon'),
    ('fr', 'quote.err_parent_required', 'devis_id ou facture_id requis'),
    ('fr', 'quote.err_default_description', 'Ligne sans description'),

    -- Toast messages
    ('fr', 'quote.toast_devis_saved', 'Devis enregistré'),
    ('fr', 'quote.toast_facture_saved', 'Facture enregistrée'),
    ('fr', 'quote.toast_devis_sent', 'Devis envoyé'),
    ('fr', 'quote.toast_devis_accepted', 'Devis accepté'),
    ('fr', 'quote.toast_devis_refused', 'Devis refusé'),
    ('fr', 'quote.toast_devis_deleted', 'Devis supprimé'),
    ('fr', 'quote.toast_devis_duplicated', 'Devis dupliqué'),
    ('fr', 'quote.toast_facture_created', 'Facture créée'),
    ('fr', 'quote.toast_facture_sent', 'Facture envoyée'),
    ('fr', 'quote.toast_facture_paid', 'Facture marquée comme payée'),
    ('fr', 'quote.toast_facture_deleted', 'Facture supprimée'),
    ('fr', 'quote.toast_facture_relance', 'Relance enregistrée pour la facture'),
    ('fr', 'quote.toast_ligne_added', 'Ligne ajoutée'),
    ('fr', 'quote.toast_ligne_deleted', 'Ligne supprimée'),

    -- Currency suffix
    ('fr', 'quote.currency', 'EUR')

  ON CONFLICT DO NOTHING;
END;
$function$;
