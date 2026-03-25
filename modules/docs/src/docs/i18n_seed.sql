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

    -- Entity labels (for _view)
    ('fr', 'docs.entity_document', 'Document'),
    ('fr', 'docs.entity_charte', 'Charte'),
    ('fr', 'docs.entity_library', 'Photothèque'),

    -- Stats
    ('fr', 'docs.stat_documents', 'Documents'),
    ('fr', 'docs.stat_chartes', 'Chartes'),
    ('fr', 'docs.stat_pages', 'Pages'),
    ('fr', 'docs.stat_draft', 'Brouillons'),
    ('fr', 'docs.stat_assets', 'Ressources'),
    ('fr', 'docs.stat_linked_docs', 'Documents liés'),

    -- Field labels
    ('fr', 'docs.col_name', 'Nom'),
    ('fr', 'docs.col_description', 'Description'),
    ('fr', 'docs.col_category', 'Catégorie'),
    ('fr', 'docs.col_format', 'Format'),
    ('fr', 'docs.col_orientation', 'Orientation'),
    ('fr', 'docs.col_charte', 'Charte'),
    ('fr', 'docs.col_status', 'Statut'),
    ('fr', 'docs.col_pages', 'Pages'),
    ('fr', 'docs.col_updated', 'Modifié'),
    ('fr', 'docs.col_width', 'Largeur'),
    ('fr', 'docs.col_height', 'Hauteur'),
    ('fr', 'docs.col_bg', 'Fond'),
    ('fr', 'docs.col_main', 'Principale'),
    ('fr', 'docs.col_accent', 'Accent'),
    ('fr', 'docs.col_text', 'Texte'),
    ('fr', 'docs.col_text_light', 'Texte secondaire'),
    ('fr', 'docs.col_border', 'Bordure'),
    ('fr', 'docs.col_heading_font', 'Police titres'),
    ('fr', 'docs.col_body_font', 'Police corps'),
    ('fr', 'docs.col_asset_count', 'Ressources'),
    ('fr', 'docs.col_design_notes', 'Notes design'),
    ('fr', 'docs.col_team_notes', 'Notes équipe'),
    ('fr', 'docs.col_email_to', 'Destinataire'),
    ('fr', 'docs.col_formality', 'Formalité'),
    ('fr', 'docs.col_personality', 'Personnalité'),

    -- Status labels
    ('fr', 'docs.status_draft', 'Brouillon'),
    ('fr', 'docs.status_generated', 'Généré'),
    ('fr', 'docs.status_signed', 'Signé'),
    ('fr', 'docs.status_archived', 'Archivé'),

    -- Category options
    ('fr', 'docs.cat_general', 'Général'),
    ('fr', 'docs.cat_confirmation', 'Confirmation'),
    ('fr', 'docs.cat_invoice', 'Facture'),
    ('fr', 'docs.cat_quote', 'Devis'),
    ('fr', 'docs.cat_menu', 'Menu'),
    ('fr', 'docs.cat_identite', 'Identité'),
    ('fr', 'docs.cat_evenement', 'Événement'),

    -- Actions
    ('fr', 'docs.action_generate', 'Générer'),
    ('fr', 'docs.action_sign', 'Signer'),
    ('fr', 'docs.action_revert', 'Repasser en brouillon'),
    ('fr', 'docs.action_archive', 'Archiver'),
    ('fr', 'docs.action_duplicate', 'Dupliquer'),
    ('fr', 'docs.action_delete', 'Supprimer'),
    ('fr', 'docs.action_update', 'Modifier'),
    ('fr', 'docs.confirm_delete', 'Supprimer définitivement ?'),
    ('fr', 'docs.confirm_generate', 'Figer le document ?'),
    ('fr', 'docs.confirm_sign', 'Signer le document ? Cette action est irréversible.'),

    -- Sections (for _view form)
    ('fr', 'docs.section_identity', 'Identité'),
    ('fr', 'docs.section_canvas', 'Canvas'),
    ('fr', 'docs.section_email', 'Email'),
    ('fr', 'docs.section_palette', 'Palette'),
    ('fr', 'docs.section_typography', 'Typographie'),
    ('fr', 'docs.section_spacing', 'Espacement'),
    ('fr', 'docs.section_voice', 'Voix de marque'),

    -- Related
    ('fr', 'docs.rel_charte', 'Charte liée'),
    ('fr', 'docs.rel_library', 'Photothèque'),
    ('fr', 'docs.rel_documents', 'Documents'),
    ('fr', 'docs.rel_assets', 'Ressources'),

    -- Section titles (legacy pgView)
    ('fr', 'docs.title_documents', 'Documents'),
    ('fr', 'docs.title_chartes', 'Chartes graphiques'),
    ('fr', 'docs.title_libraries', 'Photothèques'),
    ('fr', 'docs.title_palette', 'Palette'),
    ('fr', 'docs.title_typography', 'Typographie'),
    ('fr', 'docs.title_spacing', 'Espacement'),
    ('fr', 'docs.title_voice', 'Voix de marque'),
    ('fr', 'docs.title_canvas', 'Canvas'),
    ('fr', 'docs.title_pages', 'Pages'),
    ('fr', 'docs.title_meta', 'Métadonnées'),

    -- Detail labels (legacy pgView)
    ('fr', 'docs.label_heading_font', 'Titres'),
    ('fr', 'docs.label_body_font', 'Corps'),
    ('fr', 'docs.label_page', 'Page'),
    ('fr', 'docs.label_section', 'Section'),
    ('fr', 'docs.label_gap', 'Gap'),
    ('fr', 'docs.label_card', 'Card'),

    -- Empty states
    ('fr', 'docs.empty_no_documents', 'Aucun document'),
    ('fr', 'docs.empty_first_document', 'Créez votre premier document pour commencer.'),
    ('fr', 'docs.empty_no_chartes', 'Aucune charte'),
    ('fr', 'docs.empty_first_charte', 'Créez votre première charte graphique.'),
    ('fr', 'docs.empty_no_libraries', 'Aucune photothèque'),
    ('fr', 'docs.empty_first_library', 'Créez votre première photothèque pour composer des documents.'),

    -- Errors
    ('fr', 'docs.err_not_found', 'Document introuvable.'),
    ('fr', 'docs.err_charte_not_found', 'Charte introuvable.'),
    ('fr', 'docs.err_library_not_found', 'Photothèque introuvable.'),
    ('fr', 'docs.err_name_required', 'Le nom est obligatoire.')

  ON CONFLICT DO NOTHING;
END;
$function$;
