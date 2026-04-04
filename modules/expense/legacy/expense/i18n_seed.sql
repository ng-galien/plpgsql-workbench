CREATE OR REPLACE FUNCTION expense.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'expense.brand', 'Notes de frais'),
    ('fr', 'expense.nav_dashboard', 'Dashboard'),
    ('fr', 'expense.nav_reports', 'Notes'),
    ('fr', 'expense.nav_categories', 'Catégories'),

    -- Entity labels
    ('fr', 'expense.entity_expense_report', 'Note de frais'),
    ('fr', 'expense.entity_category', 'Catégorie de frais'),

    -- Sections
    ('fr', 'expense.section_info', 'Informations'),
    ('fr', 'expense.section_lines', 'Lignes de dépenses'),

    -- Status values
    ('fr', 'expense.status_draft', 'Brouillon'),
    ('fr', 'expense.status_submitted', 'Soumise'),
    ('fr', 'expense.status_validated', 'Validée'),
    ('fr', 'expense.status_reimbursed', 'Remboursée'),
    ('fr', 'expense.status_rejected', 'Rejetée'),

    -- Stats
    ('fr', 'expense.stat_reports', 'Notes de frais'),
    ('fr', 'expense.stat_current_total', 'Total en cours'),
    ('fr', 'expense.stat_avg_amount', 'Montant moyen'),
    ('fr', 'expense.stat_pending_validation', 'A valider'),
    ('fr', 'expense.stat_total_excl_tax', 'Total HT'),
    ('fr', 'expense.stat_total_vat', 'Total TVA'),
    ('fr', 'expense.stat_total_incl_tax', 'Total TTC'),
    ('fr', 'expense.stat_line_count', 'Lignes'),
    ('fr', 'expense.stat_total', 'Total'),

    -- Column headers
    ('fr', 'expense.col_reference', 'Référence'),
    ('fr', 'expense.col_author', 'Auteur'),
    ('fr', 'expense.col_period', 'Période'),
    ('fr', 'expense.col_lines', 'Lignes'),
    ('fr', 'expense.col_status', 'Statut'),
    ('fr', 'expense.col_total_incl_tax', 'Total TTC'),
    ('fr', 'expense.col_date', 'Date'),
    ('fr', 'expense.col_category', 'Catégorie'),
    ('fr', 'expense.col_description', 'Description'),
    ('fr', 'expense.col_km', 'Km'),
    ('fr', 'expense.col_excl_tax', 'HT'),
    ('fr', 'expense.col_vat', 'TVA'),
    ('fr', 'expense.col_incl_tax', 'TTC'),
    ('fr', 'expense.col_accounting_code', 'Code comptable'),
    ('fr', 'expense.col_start_date', 'Date début'),
    ('fr', 'expense.col_end_date', 'Date fin'),
    ('fr', 'expense.col_line_count', 'Nb lignes'),
    ('fr', 'expense.col_name', 'Nom'),

    -- Field labels
    ('fr', 'expense.field_author', 'Auteur'),
    ('fr', 'expense.field_start_date', 'Date début'),
    ('fr', 'expense.field_end_date', 'Date fin'),
    ('fr', 'expense.field_comment', 'Commentaire'),
    ('fr', 'expense.field_expense_date', 'Date'),
    ('fr', 'expense.field_category', 'Catégorie'),
    ('fr', 'expense.field_description', 'Description'),
    ('fr', 'expense.field_amount_excl_tax', 'Montant HT'),
    ('fr', 'expense.field_vat', 'TVA'),
    ('fr', 'expense.field_km', 'Km (si déplacement)'),
    ('fr', 'expense.field_status', 'Statut'),
    ('fr', 'expense.field_name', 'Nom'),
    ('fr', 'expense.field_accounting_code', 'Code comptable'),

    -- Actions
    ('fr', 'expense.action_edit', 'Modifier'),
    ('fr', 'expense.action_delete', 'Supprimer'),
    ('fr', 'expense.action_submit', 'Soumettre'),
    ('fr', 'expense.action_validate', 'Valider'),
    ('fr', 'expense.action_reject', 'Rejeter'),
    ('fr', 'expense.action_reimburse', 'Rembourser'),
    ('fr', 'expense.action_add_line', 'Ajouter une ligne'),
    ('fr', 'expense.action_new_report', 'Nouvelle note'),

    -- Confirm dialogs
    ('fr', 'expense.confirm_submit', 'Soumettre cette note pour validation ?'),
    ('fr', 'expense.confirm_validate', 'Valider cette note de frais ?'),
    ('fr', 'expense.confirm_reject', 'Rejeter cette note de frais ?'),
    ('fr', 'expense.confirm_reimburse', 'Marquer cette note comme remboursée ?'),
    ('fr', 'expense.confirm_delete', 'Supprimer cette note de frais ?'),
    ('fr', 'expense.confirm_delete_category', 'Supprimer cette catégorie ?'),

    -- Filter options
    ('fr', 'expense.filter_all', 'Tous'),
    ('fr', 'expense.filter_draft', 'Brouillon'),
    ('fr', 'expense.filter_submitted', 'Soumise'),
    ('fr', 'expense.filter_validated', 'Validée'),
    ('fr', 'expense.filter_reimbursed', 'Remboursée'),
    ('fr', 'expense.filter_rejected', 'Rejetée'),

    -- Empty states
    ('fr', 'expense.empty_no_category', 'Aucune catégorie'),
    ('fr', 'expense.empty_no_report', 'Aucune note de frais'),
    ('fr', 'expense.empty_first_report', 'Créez votre première note pour commencer.'),
    ('fr', 'expense.empty_no_results', 'Aucune note trouvée'),
    ('fr', 'expense.empty_no_line', 'Aucune ligne'),
    ('fr', 'expense.empty_add_line', 'Ajoutez des dépenses à cette note.'),

    -- Error messages
    ('fr', 'expense.err_id_required', 'ID requis.'),
    ('fr', 'expense.err_fields_required', 'Auteur, date début et date fin sont requis.'),
    ('fr', 'expense.err_date_order', 'La date de fin doit être postérieure à la date de début.'),
    ('fr', 'expense.err_note_not_modifiable', 'Note introuvable ou non modifiable.'),
    ('fr', 'expense.err_line_fields', 'Note, date, description et montant HT requis.'),
    ('fr', 'expense.err_note_not_found', 'Note introuvable.'),
    ('fr', 'expense.err_not_draft', 'Ajout impossible : la note n''est plus en brouillon.'),
    ('fr', 'expense.err_no_lines', 'Impossible de soumettre une note sans ligne.'),
    ('fr', 'expense.err_not_draft_submit', 'Note introuvable ou pas en brouillon.'),
    ('fr', 'expense.err_not_submitted', 'Note introuvable ou pas en statut soumise.'),
    ('fr', 'expense.err_not_validated', 'Note introuvable ou pas en statut validée.'),

    -- Toast messages
    ('fr', 'expense.toast_line_added', 'Ligne ajoutée.'),
    ('fr', 'expense.toast_note_created', 'Note créée.'),
    ('fr', 'expense.toast_note_updated', 'Note modifiée.'),
    ('fr', 'expense.toast_note_submitted', 'Note soumise pour validation.'),
    ('fr', 'expense.toast_note_validated', 'Note validée.'),
    ('fr', 'expense.toast_note_rejected', 'Note rejetée.'),
    ('fr', 'expense.toast_note_reimbursed', 'Note remboursée')

  ON CONFLICT DO NOTHING;
END;
$function$;
