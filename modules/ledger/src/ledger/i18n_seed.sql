CREATE OR REPLACE FUNCTION ledger.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'ledger.brand', 'Comptabilité'),
    ('fr', 'ledger.nav_dashboard', 'Tableau de bord'),
    ('fr', 'ledger.nav_entries', 'Écritures'),
    ('fr', 'ledger.nav_accounts', 'Plan comptable'),
    ('fr', 'ledger.nav_balance', 'Balance'),
    ('fr', 'ledger.nav_exercice', 'Exercice'),
    ('fr', 'ledger.nav_fiscal_year', 'Exercice'),
    ('fr', 'ledger.nav_tva', 'TVA'),
    ('fr', 'ledger.nav_vat', 'TVA'),
    ('fr', 'ledger.nav_bilan', 'Bilan'),
    ('fr', 'ledger.nav_balance_sheet', 'Bilan'),

    -- Account types
    ('fr', 'ledger.type_asset', 'Actif'),
    ('fr', 'ledger.type_liability', 'Passif'),
    ('fr', 'ledger.type_equity', 'Capitaux'),
    ('fr', 'ledger.type_revenue', 'Produit'),
    ('fr', 'ledger.type_expense', 'Charge'),

    -- Badges
    ('fr', 'ledger.badge_posted', 'Validée'),
    ('fr', 'ledger.badge_draft', 'Brouillon'),
    ('fr', 'ledger.badge_closed', 'Clôturé'),
    ('fr', 'ledger.badge_open', 'Ouvert'),
    ('fr', 'ledger.badge_active', 'Actif'),
    ('fr', 'ledger.badge_inactive', 'Inactif'),

    -- Stats / KPIs
    ('fr', 'ledger.stat_bank_balance', 'Solde banque'),
    ('fr', 'ledger.stat_monthly_revenue', 'CA du mois'),
    ('fr', 'ledger.stat_monthly_expenses', 'Charges du mois'),
    ('fr', 'ledger.stat_result', 'Résultat'),
    ('fr', 'ledger.stat_total_debit', 'Total débit'),
    ('fr', 'ledger.stat_total_credit', 'Total crédit'),
    ('fr', 'ledger.stat_gap', 'Écart'),
    ('fr', 'ledger.stat_balance_ok', 'Équilibre OK'),
    ('fr', 'ledger.stat_imbalance', 'DÉSÉQUILIBRE'),
    ('fr', 'ledger.stat_status', 'Statut'),
    ('fr', 'ledger.stat_revenue', 'Produits'),
    ('fr', 'ledger.stat_expenses', 'Charges'),
    ('fr', 'ledger.stat_benefit', 'Bénéfice'),
    ('fr', 'ledger.stat_deficit', 'Déficit'),
    ('fr', 'ledger.stat_entries', 'Écritures'),
    ('fr', 'ledger.stat_drafts', 'Brouillons'),
    ('fr', 'ledger.stat_drafts_hint', 'À valider avant clôture'),
    ('fr', 'ledger.stat_balance', 'Solde'),
    ('fr', 'ledger.stat_result_net', 'Résultat net'),
    ('fr', 'ledger.stat_tva_collected', 'TVA collectée'),
    ('fr', 'ledger.stat_tva_deductible', 'TVA déductible'),
    ('fr', 'ledger.stat_tva_due', 'TVA à reverser'),
    ('fr', 'ledger.stat_tva_credit', 'Crédit de TVA'),

    -- Column headers
    ('fr', 'ledger.col_date', 'Date'),
    ('fr', 'ledger.col_reference', 'Référence'),
    ('fr', 'ledger.col_description', 'Description'),
    ('fr', 'ledger.col_amount', 'Montant'),
    ('fr', 'ledger.col_status', 'Statut'),
    ('fr', 'ledger.col_code', 'Code'),
    ('fr', 'ledger.col_label', 'Libellé'),
    ('fr', 'ledger.col_type', 'Type'),
    ('fr', 'ledger.col_balance', 'Solde'),
    ('fr', 'ledger.col_debit', 'Débit'),
    ('fr', 'ledger.col_credit', 'Crédit'),
    ('fr', 'ledger.col_account', 'Compte'),
    ('fr', 'ledger.col_cumulative', 'Solde cumulé'),
    ('fr', 'ledger.col_active', 'Actif'),
    ('fr', 'ledger.col_lines', 'Lignes'),

    -- Form fields
    ('fr', 'ledger.field_date', 'Date'),
    ('fr', 'ledger.field_reference', 'Référence'),
    ('fr', 'ledger.field_description', 'Description'),
    ('fr', 'ledger.field_account', 'Compte'),
    ('fr', 'ledger.field_choose', '— Choisir —'),
    ('fr', 'ledger.field_debit', 'Débit'),
    ('fr', 'ledger.field_credit', 'Crédit'),
    ('fr', 'ledger.field_label', 'Libellé'),
    ('fr', 'ledger.field_parent_code', 'Code parent'),

    -- Buttons / Actions
    ('fr', 'ledger.btn_new_entry', 'Nouvelle écriture'),
    ('fr', 'ledger.btn_save', 'Enregistrer'),
    ('fr', 'ledger.btn_add', 'Ajouter'),
    ('fr', 'ledger.btn_edit', 'Modifier'),
    ('fr', 'ledger.btn_post', 'Valider'),
    ('fr', 'ledger.btn_delete', 'Supprimer'),
    ('fr', 'ledger.btn_delete_short', 'Suppr.'),
    ('fr', 'ledger.btn_balance_check', 'Balance de vérification'),
    ('fr', 'ledger.btn_bilan_pl', 'Bilan P&L'),

    -- Section / Page titles
    ('fr', 'ledger.title_recent_entries', 'Écritures récentes'),
    ('fr', 'ledger.title_add_line', 'Ajouter une ligne'),
    ('fr', 'ledger.title_tva_detail', 'Détail mouvements TVA'),
    ('fr', 'ledger.title_new_entry', 'Nouvelle écriture'),
    ('fr', 'ledger.title_revenue', 'Produits (classe 7)'),
    ('fr', 'ledger.title_expenses', 'Charges (classe 6)'),
    ('fr', 'ledger.title_total', 'Total'),
    ('fr', 'ledger.title_period', 'Période'),

    -- Empty states
    ('fr', 'ledger.empty_no_entry', 'Aucune écriture'),
    ('fr', 'ledger.empty_first_entry', 'Créez votre première écriture.'),
    ('fr', 'ledger.empty_first_entry_accounting', 'Créez votre première écriture comptable.'),
    ('fr', 'ledger.empty_no_account', 'Aucun compte'),
    ('fr', 'ledger.empty_chart_empty', 'Le plan comptable est vide.'),
    ('fr', 'ledger.empty_account_not_found', 'Compte introuvable'),
    ('fr', 'ledger.empty_no_movement', 'Aucun mouvement'),
    ('fr', 'ledger.empty_no_posted_lines', 'Ce compte n''a pas encore de lignes validées.'),
    ('fr', 'ledger.empty_no_line', 'Aucune ligne'),
    ('fr', 'ledger.empty_add_lines', 'Ajoutez des lignes à cette écriture.'),
    ('fr', 'ledger.empty_entry_not_found', 'Écriture introuvable'),
    ('fr', 'ledger.empty_no_tva', 'Aucun mouvement TVA sur la période'),
    ('fr', 'ledger.empty_no_movement_on', 'Aucun mouvement sur'),
    ('fr', 'ledger.empty_no_posted_period', 'Ce compte n''a pas d''écriture validée sur la période.'),
    ('fr', 'ledger.empty_no_revenue_on', 'Aucun produit sur'),
    ('fr', 'ledger.empty_no_expense_on', 'Aucune charge sur'),

    -- Error messages (UI-visible)
    ('fr', 'ledger.err_posted_readonly', 'Écriture validée : modification impossible.'),
    ('fr', 'ledger.err_unbalanced_prefix', 'Écriture déséquilibrée : débit'),
    ('fr', 'ledger.err_duplicate_facture', 'Cette facture a déjà une écriture comptable'),
    ('fr', 'ledger.err_duplicate_expense', 'Cette note de frais a déjà une écriture comptable'),

    -- Toast messages
    ('fr', 'ledger.toast_entry_saved', 'Écriture enregistrée'),
    ('fr', 'ledger.toast_entry_posted', 'Écriture validée'),
    ('fr', 'ledger.toast_entry_deleted', 'Écriture supprimée'),
    ('fr', 'ledger.toast_line_added', 'Ligne ajoutée'),
    ('fr', 'ledger.toast_line_deleted', 'Ligne supprimée'),
    ('fr', 'ledger.toast_exercice_closed', 'Exercice clôturé'),
    ('fr', 'ledger.toast_entry_from_facture', 'Écriture créée depuis facture'),
    ('fr', 'ledger.toast_entry_from_invoice', 'Écriture créée depuis facture'),
    ('fr', 'ledger.toast_entry_from_expense', 'Écriture NDF créée'),

    -- Confirm dialogs
    ('fr', 'ledger.confirm_post_entry', 'Valider cette écriture ? Elle deviendra immutable.'),
    ('fr', 'ledger.confirm_delete_draft', 'Supprimer ce brouillon ?'),
    ('fr', 'ledger.confirm_delete_line', 'Supprimer cette ligne ?'),
    ('fr', 'ledger.confirm_delete_account', 'Supprimer ce compte ?'),
    ('fr', 'ledger.confirm_close_exercice', 'Clôturer définitivement l''exercice'),
    ('fr', 'ledger.confirm_close_suffix', '? Cette action est irréversible.'),

    -- Exercice / Clôture
    ('fr', 'ledger.closed_on', 'Clôturé le'),
    ('fr', 'ledger.result_recorded', 'résultat enregistré'),
    ('fr', 'ledger.btn_close_exercice', 'Clôturer l''exercice'),
    ('fr', 'ledger.err_already_closed', 'est déjà clôturé'),
    ('fr', 'ledger.err_drafts_remaining', 'écriture(s) brouillon — validez-les avant clôture'),
    ('fr', 'ledger.total_revenue', 'Total produits'),
    ('fr', 'ledger.total_expenses', 'Total charges'),

    -- Entity labels (_view)
    ('fr', 'ledger.entity_journal_entry', 'Écriture comptable'),
    ('fr', 'ledger.entity_account', 'Compte'),
    ('fr', 'ledger.section_entry', 'Écriture'),
    ('fr', 'ledger.section_account', 'Compte'),
    ('fr', 'ledger.related_facture', 'Facture associée'),
    ('fr', 'ledger.related_invoice', 'Facture associée'),
    ('fr', 'ledger.related_expense_note', 'Note de frais associée')

  ON CONFLICT DO NOTHING;
END;
$function$;
