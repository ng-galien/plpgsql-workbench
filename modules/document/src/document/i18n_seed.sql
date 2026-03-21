CREATE OR REPLACE FUNCTION document.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'document.brand', 'Documents'),
    ('fr', 'document.nav_documents', 'Documents'),
    ('fr', 'document.nav_chartes', 'Chartes'),

    -- Stats
    ('fr', 'document.stat_documents', 'Documents'),
    ('fr', 'document.stat_chartes', 'Chartes'),
    ('fr', 'document.stat_pages', 'Pages'),
    ('fr', 'document.stat_draft', 'Brouillons'),

    -- Table headers
    ('fr', 'document.col_name', 'Nom'),
    ('fr', 'document.col_category', 'Catégorie'),
    ('fr', 'document.col_format', 'Format'),
    ('fr', 'document.col_charte', 'Charte'),
    ('fr', 'document.col_status', 'Statut'),
    ('fr', 'document.col_pages', 'Pages'),
    ('fr', 'document.col_updated', 'Modifié'),
    ('fr', 'document.col_colors', 'Couleurs'),
    ('fr', 'document.col_fonts', 'Polices'),

    -- Status labels
    ('fr', 'document.status_draft', 'Brouillon'),
    ('fr', 'document.status_generated', 'Généré'),
    ('fr', 'document.status_signed', 'Signé'),
    ('fr', 'document.status_archived', 'Archivé'),

    -- Category labels
    ('fr', 'document.cat_general', 'Général'),
    ('fr', 'document.cat_confirmation', 'Confirmation'),
    ('fr', 'document.cat_invoice', 'Facture'),
    ('fr', 'document.cat_quote', 'Devis'),

    -- Buttons / Actions
    ('fr', 'document.btn_new_document', 'Nouveau document'),
    ('fr', 'document.btn_new_charte', 'Nouvelle charte'),
    ('fr', 'document.btn_save', 'Enregistrer'),
    ('fr', 'document.btn_delete', 'Supprimer'),
    ('fr', 'document.btn_duplicate', 'Dupliquer'),

    -- Empty states
    ('fr', 'document.empty_no_documents', 'Aucun document'),
    ('fr', 'document.empty_first_document', 'Créez votre premier document pour commencer.'),
    ('fr', 'document.empty_no_chartes', 'Aucune charte'),
    ('fr', 'document.empty_first_charte', 'Créez votre première charte graphique.'),

    -- Section titles
    ('fr', 'document.title_documents', 'Documents'),
    ('fr', 'document.title_chartes', 'Chartes graphiques'),

    -- Errors
    ('fr', 'document.err_not_found', 'Document introuvable.'),
    ('fr', 'document.err_charte_not_found', 'Charte introuvable.'),
    ('fr', 'document.err_name_required', 'Le nom est obligatoire.')

  ON CONFLICT DO NOTHING;
END;
$function$;
