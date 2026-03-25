CREATE OR REPLACE FUNCTION quote.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'quote.brand', 'Facturation'),
    ('fr', 'quote.nav_dashboard', 'Dashboard'),
    ('fr', 'quote.nav_estimates', 'Devis'),
    ('fr', 'quote.nav_invoices', 'Factures'),

    -- Statuses (English keys matching DB values)
    ('fr', 'quote.status_draft', 'Brouillon'),
    ('fr', 'quote.status_sent', 'Envoyé(e)'),
    ('fr', 'quote.status_accepted', 'Accepté'),
    ('fr', 'quote.status_declined', 'Refusé'),
    ('fr', 'quote.status_paid', 'Payée'),
    ('fr', 'quote.status_overdue', 'Relance'),

    -- Column headers
    ('fr', 'quote.col_number', 'Numéro'),
    ('fr', 'quote.col_client', 'Client'),
    ('fr', 'quote.col_subject', 'Objet'),
    ('fr', 'quote.col_status', 'Statut'),
    ('fr', 'quote.col_total_ttc', 'Total TTC'),
    ('fr', 'quote.col_date', 'Date'),
    ('fr', 'quote.col_description', 'Description'),
    ('fr', 'quote.col_quantity', 'Qté'),
    ('fr', 'quote.col_unit', 'Unité'),
    ('fr', 'quote.col_unit_price', 'PU HT'),
    ('fr', 'quote.col_tva', 'TVA'),
    ('fr', 'quote.col_amount_ht', 'Montant HT'),

    -- Field labels
    ('fr', 'quote.field_number', 'Numéro'),
    ('fr', 'quote.field_client', 'Client'),
    ('fr', 'quote.field_subject', 'Objet'),
    ('fr', 'quote.field_status', 'Statut'),
    ('fr', 'quote.field_validity', 'Validité'),
    ('fr', 'quote.field_validity_days', 'Validité (jours)'),
    ('fr', 'quote.field_date', 'Date'),
    ('fr', 'quote.field_total_ht', 'Total HT'),
    ('fr', 'quote.field_total_tva', 'Total TVA'),
    ('fr', 'quote.field_total_ttc', 'Total TTC'),
    ('fr', 'quote.field_estimate', 'Devis'),
    ('fr', 'quote.field_paid_at', 'Payée le'),
    ('fr', 'quote.field_notes', 'Notes'),
    ('fr', 'quote.field_days', 'jours'),
    ('fr', 'quote.field_direct_invoice', 'Facture directe'),
    ('fr', 'quote.field_select_placeholder', '— Choisir —'),
    ('fr', 'quote.field_description_placeholder', 'Renseignée depuis l''article si sélectionné'),
    ('fr', 'quote.field_quantity', 'Quantité'),
    ('fr', 'quote.field_unit_price', 'Prix unitaire HT'),
    ('fr', 'quote.field_article', 'Article (catalogue)'),
    ('fr', 'quote.field_article_placeholder', 'Chercher un article...'),

    -- Units
    ('fr', 'quote.unit_u', 'Unité'),
    ('fr', 'quote.unit_h', 'Heure'),
    ('fr', 'quote.unit_m', 'Mètre'),
    ('fr', 'quote.unit_m2', 'm²'),
    ('fr', 'quote.unit_m3', 'm³'),
    ('fr', 'quote.unit_flat', 'Forfait'),

    -- Stats
    ('fr', 'quote.stat_estimates_pending', 'Devis en cours'),
    ('fr', 'quote.stat_invoices_unpaid', 'Factures impayées'),
    ('fr', 'quote.stat_revenue_month', 'CA du mois'),
    ('fr', 'quote.stat_acceptance_rate', 'Taux acceptation'),
    ('fr', 'quote.stat_total_ht', 'Total HT'),
    ('fr', 'quote.stat_total_tva', 'Total TVA'),
    ('fr', 'quote.stat_total_ttc', 'Total TTC'),

    -- Tab titles
    ('fr', 'quote.tab_recent_estimates', 'Devis récents'),
    ('fr', 'quote.tab_recent_invoices', 'Factures récentes'),

    -- Buttons / Actions
    ('fr', 'quote.btn_new_estimate', 'Nouveau devis'),
    ('fr', 'quote.btn_new_invoice', 'Nouvelle facture'),
    ('fr', 'quote.btn_edit', 'Modifier'),
    ('fr', 'quote.btn_add', 'Ajouter'),
    ('fr', 'quote.btn_delete_line', 'Suppr.'),
    ('fr', 'quote.btn_create_estimate', 'Créer le devis'),
    ('fr', 'quote.btn_create_invoice', 'Créer la facture'),
    ('fr', 'quote.btn_update', 'Mettre à jour'),

    -- Page / Section titles
    ('fr', 'quote.title_estimates', 'Devis'),
    ('fr', 'quote.title_invoices', 'Factures'),
    ('fr', 'quote.title_edit', 'Modifier'),
    ('fr', 'quote.title_new_estimate', 'Nouveau devis'),
    ('fr', 'quote.title_new_invoice', 'Nouvelle facture'),
    ('fr', 'quote.title_add_line', 'Ajouter une ligne'),
    ('fr', 'quote.title_legal_notices', 'Mentions légales'),

    -- Entity labels (_view contract)
    ('fr', 'quote.entity_estimate', 'Devis'),
    ('fr', 'quote.entity_invoice', 'Facture'),

    -- Section labels (form)
    ('fr', 'quote.section_general', 'Informations générales'),

    -- Action labels (_view actions catalog)
    ('fr', 'quote.action_send', 'Envoyer'),
    ('fr', 'quote.action_accept', 'Accepter'),
    ('fr', 'quote.action_decline', 'Refuser'),
    ('fr', 'quote.action_invoice', 'Créer la facture'),
    ('fr', 'quote.action_duplicate', 'Dupliquer'),
    ('fr', 'quote.action_delete', 'Supprimer'),
    ('fr', 'quote.action_pay', 'Marquer payée'),
    ('fr', 'quote.action_remind', 'Relancer'),

    -- Confirm dialogs
    ('fr', 'quote.confirm_send_estimate', 'Marquer ce devis comme envoyé ?'),
    ('fr', 'quote.confirm_delete_estimate', 'Supprimer ce brouillon ?'),
    ('fr', 'quote.confirm_accept_estimate', 'Marquer ce devis comme accepté ?'),
    ('fr', 'quote.confirm_decline_estimate', 'Marquer ce devis comme refusé ?'),
    ('fr', 'quote.confirm_invoice_estimate', 'Créer une facture depuis ce devis ?'),
    ('fr', 'quote.confirm_duplicate_estimate', 'Dupliquer ce devis en brouillon ?'),
    ('fr', 'quote.confirm_send_invoice', 'Marquer cette facture comme envoyée ?'),
    ('fr', 'quote.confirm_delete_invoice', 'Supprimer ce brouillon ?'),
    ('fr', 'quote.confirm_pay_invoice', 'Marquer cette facture comme payée ?'),
    ('fr', 'quote.confirm_remind_invoice', 'Relancer cette facture ?'),
    ('fr', 'quote.confirm_delete_line', 'Supprimer cette ligne ?'),

    -- Empty states
    ('fr', 'quote.empty_no_estimates', 'Aucun devis'),
    ('fr', 'quote.empty_first_estimate', 'Créez votre premier devis pour commencer.'),
    ('fr', 'quote.empty_no_invoices', 'Aucune facture'),
    ('fr', 'quote.empty_invoices_appear', 'Les factures apparaîtront ici.'),
    ('fr', 'quote.empty_no_lines', 'Aucune ligne'),
    ('fr', 'quote.empty_add_lines', 'Ajoutez des lignes à ce devis.'),
    ('fr', 'quote.empty_not_found_estimate', 'Devis introuvable'),
    ('fr', 'quote.empty_not_found_invoice', 'Facture introuvable'),
    ('fr', 'quote.empty_edit_impossible', 'Modification impossible'),
    ('fr', 'quote.empty_drafts_only', 'Seuls les brouillons sont modifiables.'),

    -- Error messages
    ('fr', 'quote.err_draft_only', 'Seuls les brouillons sont modifiables'),
    ('fr', 'quote.err_draft_delete_only', 'Seuls les brouillons peuvent être supprimés'),
    ('fr', 'quote.err_not_found_estimate', 'Devis introuvable'),
    ('fr', 'quote.err_not_found_invoice', 'Facture introuvable'),
    ('fr', 'quote.err_not_found_line', 'Ligne introuvable'),
    ('fr', 'quote.err_accepted_only', 'Seuls les devis acceptés peuvent être facturés'),
    ('fr', 'quote.err_draft_lines_only', 'Lignes modifiables uniquement sur un brouillon'),
    ('fr', 'quote.err_parent_required', 'estimate_id ou invoice_id requis'),
    ('fr', 'quote.err_default_description', 'Ligne sans description'),

    -- Toast messages
    ('fr', 'quote.toast_estimate_saved', 'Devis enregistré'),
    ('fr', 'quote.toast_invoice_saved', 'Facture enregistrée'),
    ('fr', 'quote.toast_estimate_sent', 'Devis envoyé'),
    ('fr', 'quote.toast_estimate_accepted', 'Devis accepté'),
    ('fr', 'quote.toast_estimate_declined', 'Devis refusé'),
    ('fr', 'quote.toast_estimate_deleted', 'Devis supprimé'),
    ('fr', 'quote.toast_estimate_duplicated', 'Devis dupliqué'),
    ('fr', 'quote.toast_invoice_created', 'Facture créée'),
    ('fr', 'quote.toast_invoice_sent', 'Facture envoyée'),
    ('fr', 'quote.toast_invoice_paid', 'Facture marquée comme payée'),
    ('fr', 'quote.toast_invoice_deleted', 'Facture supprimée'),
    ('fr', 'quote.toast_invoice_reminded', 'Relance enregistrée pour la facture'),
    ('fr', 'quote.toast_line_added', 'Ligne ajoutée'),
    ('fr', 'quote.toast_line_deleted', 'Ligne supprimée'),

    -- Related entity labels
    ('fr', 'quote.related_invoices', 'Factures liées'),
    ('fr', 'quote.related_estimate', 'Devis source'),

    -- Currency
    ('fr', 'quote.currency', 'EUR')

  ON CONFLICT DO NOTHING;
END;
$function$;
