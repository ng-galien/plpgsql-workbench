CREATE OR REPLACE FUNCTION expense.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'expense.brand', 'Notes de frais'),
    ('fr', 'expense.nav_dashboard', 'Dashboard'),
    ('fr', 'expense.nav_notes', 'Notes'),
    ('fr', 'expense.nav_categories', 'Catégories'),

    -- Entity labels (_view)
    ('fr', 'expense.entity_note', 'Note de frais'),
    ('fr', 'expense.entity_categorie', 'Catégorie de frais'),

    -- Sections (_view)
    ('fr', 'expense.section_info', 'Informations'),
    ('fr', 'expense.section_lignes', 'Lignes de dépenses'),

    -- Statuts
    ('fr', 'expense.statut_brouillon', 'Brouillon'),
    ('fr', 'expense.statut_soumise', 'Soumise'),
    ('fr', 'expense.statut_validee', 'Validée'),
    ('fr', 'expense.statut_remboursee', 'Remboursée'),
    ('fr', 'expense.statut_rejetee', 'Rejetée'),

    -- Stats
    ('fr', 'expense.stat_notes', 'Notes de frais'),
    ('fr', 'expense.stat_total_en_cours', 'Total en cours'),
    ('fr', 'expense.stat_montant_moyen', 'Montant moyen'),
    ('fr', 'expense.stat_a_valider', 'A valider'),
    ('fr', 'expense.stat_total_ht', 'Total HT'),
    ('fr', 'expense.stat_total_tva', 'Total TVA'),
    ('fr', 'expense.stat_total_ttc', 'Total TTC'),
    ('fr', 'expense.stat_nb_lignes', 'Lignes'),
    ('fr', 'expense.stat_total', 'Total'),

    -- Table headers
    ('fr', 'expense.col_reference', 'Référence'),
    ('fr', 'expense.col_auteur', 'Auteur'),
    ('fr', 'expense.col_periode', 'Période'),
    ('fr', 'expense.col_lignes', 'Lignes'),
    ('fr', 'expense.col_statut', 'Statut'),
    ('fr', 'expense.col_total_ttc', 'Total TTC'),
    ('fr', 'expense.col_date', 'Date'),
    ('fr', 'expense.col_categorie', 'Catégorie'),
    ('fr', 'expense.col_description', 'Description'),
    ('fr', 'expense.col_km', 'Km'),
    ('fr', 'expense.col_ht', 'HT'),
    ('fr', 'expense.col_tva', 'TVA'),
    ('fr', 'expense.col_ttc', 'TTC'),
    ('fr', 'expense.col_code_comptable', 'Code comptable'),
    ('fr', 'expense.col_date_debut', 'Date début'),
    ('fr', 'expense.col_date_fin', 'Date fin'),
    ('fr', 'expense.col_nb_lignes', 'Nb lignes'),
    ('fr', 'expense.col_nom', 'Nom'),

    -- Field labels
    ('fr', 'expense.field_auteur', 'Auteur'),
    ('fr', 'expense.field_date_debut', 'Date début'),
    ('fr', 'expense.field_date_fin', 'Date fin'),
    ('fr', 'expense.field_commentaire', 'Commentaire'),
    ('fr', 'expense.field_date_depense', 'Date'),
    ('fr', 'expense.field_categorie', 'Catégorie'),
    ('fr', 'expense.field_description', 'Description'),
    ('fr', 'expense.field_montant_ht', 'Montant HT'),
    ('fr', 'expense.field_tva', 'TVA'),
    ('fr', 'expense.field_km', 'Km (si déplacement)'),
    ('fr', 'expense.field_statut', 'Statut'),
    ('fr', 'expense.field_nom', 'Nom'),
    ('fr', 'expense.field_code_comptable', 'Code comptable'),

    -- DL labels (note detail)
    ('fr', 'expense.dl_reference', 'Référence'),
    ('fr', 'expense.dl_auteur', 'Auteur'),
    ('fr', 'expense.dl_periode', 'Période'),
    ('fr', 'expense.dl_statut', 'Statut'),
    ('fr', 'expense.dl_commentaire', 'Commentaire'),

    -- Buttons / Actions
    ('fr', 'expense.btn_nouvelle_note', 'Nouvelle note'),
    ('fr', 'expense.btn_creer_note', 'Créer la note'),
    ('fr', 'expense.btn_modifier', 'Modifier'),
    ('fr', 'expense.btn_filtrer', 'Filtrer'),
    ('fr', 'expense.btn_ajouter_ligne', 'Ajouter la ligne'),
    ('fr', 'expense.btn_action_ajouter_ligne', 'Ajouter une ligne'),
    ('fr', 'expense.btn_soumettre', 'Soumettre'),
    ('fr', 'expense.btn_valider', 'Valider'),
    ('fr', 'expense.btn_rejeter', 'Rejeter'),
    ('fr', 'expense.btn_rembourser', 'Rembourser'),

    -- Actions (_view)
    ('fr', 'expense.action_edit', 'Modifier'),
    ('fr', 'expense.action_delete', 'Supprimer'),
    ('fr', 'expense.action_submit', 'Soumettre'),
    ('fr', 'expense.action_validate', 'Valider'),
    ('fr', 'expense.action_reject', 'Rejeter'),
    ('fr', 'expense.action_reimburse', 'Rembourser'),
    ('fr', 'expense.action_add_ligne', 'Ajouter une ligne'),

    -- Confirm dialogs
    ('fr', 'expense.confirm_soumettre', 'Soumettre cette note pour validation ?'),
    ('fr', 'expense.confirm_valider', 'Valider cette note de frais ?'),
    ('fr', 'expense.confirm_rejeter', 'Rejeter cette note de frais ?'),
    ('fr', 'expense.confirm_rembourser', 'Marquer cette note comme remboursée ?'),
    ('fr', 'expense.confirm_delete', 'Supprimer cette note de frais ?'),
    ('fr', 'expense.confirm_delete_categorie', 'Supprimer cette catégorie ?'),

    -- Filter options
    ('fr', 'expense.filter_tous', 'Tous'),
    ('fr', 'expense.filter_brouillon', 'Brouillon'),
    ('fr', 'expense.filter_soumise', 'Soumise'),
    ('fr', 'expense.filter_validee', 'Validée'),
    ('fr', 'expense.filter_remboursee', 'Remboursée'),
    ('fr', 'expense.filter_rejetee', 'Rejetée'),

    -- Count suffixes
    ('fr', 'expense.count_lignes', 'ligne(s)'),

    -- Empty states
    ('fr', 'expense.empty_no_categorie', 'Aucune catégorie'),
    ('fr', 'expense.empty_no_note', 'Aucune note de frais'),
    ('fr', 'expense.empty_first_note', 'Créez votre première note pour commencer.'),
    ('fr', 'expense.empty_no_results', 'Aucune note trouvée'),
    ('fr', 'expense.empty_no_ligne', 'Aucune ligne'),
    ('fr', 'expense.empty_add_ligne', 'Ajoutez des dépenses à cette note.'),

    -- Error messages
    ('fr', 'expense.err_id_requis', 'ID requis.'),
    ('fr', 'expense.err_note_id_requis', 'note_id requis'),
    ('fr', 'expense.err_id_requis_detail', 'Spécifiez un identifiant de note.'),
    ('fr', 'expense.err_not_found', 'Note introuvable'),
    ('fr', 'expense.err_not_found_detail', 'La note n''existe pas.'),
    ('fr', 'expense.err_not_modifiable', 'Modification impossible'),
    ('fr', 'expense.err_not_modifiable_detail', 'Seules les notes en brouillon peuvent être modifiées.'),
    ('fr', 'expense.err_fields_requis', 'Auteur, date début et date fin sont requis.'),
    ('fr', 'expense.err_date_order', 'La date de fin doit être postérieure à la date de début.'),
    ('fr', 'expense.err_note_or_modifiable', 'Note introuvable ou non modifiable.'),
    ('fr', 'expense.err_ligne_fields', 'Note, date, description et montant HT requis.'),
    ('fr', 'expense.err_ligne_not_found', 'Note introuvable.'),
    ('fr', 'expense.err_not_brouillon', 'Ajout impossible : la note n''est plus en brouillon.'),
    ('fr', 'expense.err_no_ligne', 'Impossible de soumettre une note sans ligne.'),
    ('fr', 'expense.err_not_brouillon_submit', 'Note introuvable ou pas en brouillon.'),
    ('fr', 'expense.err_not_soumise', 'Note introuvable ou pas en statut soumise.'),
    ('fr', 'expense.err_not_validee', 'Note introuvable ou pas en statut validée.'),

    -- Toast messages
    ('fr', 'expense.toast_ligne_ajoutee', 'Ligne ajoutée.'),
    ('fr', 'expense.toast_note_creee', 'Note créée.'),
    ('fr', 'expense.toast_note_modifiee', 'Note modifiée.'),
    ('fr', 'expense.toast_note_soumise', 'Note soumise pour validation.'),
    ('fr', 'expense.toast_note_validee', 'Note validée.'),
    ('fr', 'expense.toast_note_rejetee', 'Note rejetée.'),
    ('fr', 'expense.toast_note_remboursee', 'Note remboursée')

  ON CONFLICT DO NOTHING;
END;
$function$;
