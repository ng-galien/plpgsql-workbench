CREATE OR REPLACE FUNCTION docs.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'docs.brand', 'Documents'),
    ('fr', 'docs.nav_documents', 'Documents'),
    ('fr', 'docs.nav_chartes', 'Chartes'),
    ('fr', 'docs.nav_libraries', 'Photothèque'),

    -- Stats
    ('fr', 'docs.stat_documents', 'Documents'),
    ('fr', 'docs.stat_chartes', 'Chartes'),
    ('fr', 'docs.stat_pages', 'Pages'),
    ('fr', 'docs.stat_draft', 'Brouillons'),

    -- Table headers
    ('fr', 'docs.col_name', 'Nom'),
    ('fr', 'docs.col_category', 'Catégorie'),
    ('fr', 'docs.col_format', 'Format'),
    ('fr', 'docs.col_charte', 'Charte'),
    ('fr', 'docs.col_status', 'Statut'),
    ('fr', 'docs.col_pages', 'Pages'),
    ('fr', 'docs.col_updated', 'Modifié'),
    ('fr', 'docs.col_colors', 'Couleurs'),
    ('fr', 'docs.col_fonts', 'Polices'),

    -- Status labels
    ('fr', 'docs.status_draft', 'Brouillon'),
    ('fr', 'docs.status_generated', 'Généré'),
    ('fr', 'docs.status_signed', 'Signé'),
    ('fr', 'docs.status_archived', 'Archivé'),

    -- Category labels
    ('fr', 'docs.cat_general', 'Général'),
    ('fr', 'docs.cat_confirmation', 'Confirmation'),
    ('fr', 'docs.cat_invoice', 'Facture'),
    ('fr', 'docs.cat_quote', 'Devis'),

    -- Buttons / Actions
    ('fr', 'docs.btn_new_document', 'Nouveau document'),
    ('fr', 'docs.btn_new_charte', 'Nouvelle charte'),
    ('fr', 'docs.btn_save', 'Enregistrer'),
    ('fr', 'docs.btn_delete', 'Supprimer'),
    ('fr', 'docs.btn_duplicate', 'Dupliquer'),

    -- Empty states
    ('fr', 'docs.empty_no_documents', 'Aucun document'),
    ('fr', 'docs.empty_first_document', 'Créez votre premier document pour commencer.'),
    ('fr', 'docs.empty_no_chartes', 'Aucune charte'),
    ('fr', 'docs.empty_first_charte', 'Créez votre première charte graphique.'),
    ('fr', 'docs.empty_no_libraries', 'Aucune photothèque'),
    ('fr', 'docs.empty_first_library', 'Créez votre première photothèque pour composer des documents.'),

    -- Section titles
    ('fr', 'docs.title_documents', 'Documents'),
    ('fr', 'docs.title_chartes', 'Chartes graphiques'),
    ('fr', 'docs.title_libraries', 'Photothèques'),

    -- Errors
    ('fr', 'docs.err_not_found', 'Document introuvable.'),
    ('fr', 'docs.err_charte_not_found', 'Charte introuvable.'),
    ('fr', 'docs.err_name_required', 'Le nom est obligatoire.')

  ON CONFLICT DO NOTHING;
END;
$function$;
