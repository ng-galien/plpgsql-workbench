CREATE OR REPLACE FUNCTION asset.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'asset.brand', 'Assets'),
    ('fr', 'asset.nav_assets', 'Photothèque'),
    ('fr', 'asset.nav_upload', 'Upload'),

    -- Entity
    ('fr', 'asset.entity_asset', 'Asset'),

    -- Status
    ('fr', 'asset.status_to_classify', 'À classifier'),
    ('fr', 'asset.status_classified', 'Classifié'),
    ('fr', 'asset.status_archived', 'Archivé'),

    -- Field labels
    ('fr', 'asset.field_search', 'Recherche titre/description'),
    ('fr', 'asset.field_status', 'Statut'),
    ('fr', 'asset.field_tags', 'Tags'),
    ('fr', 'asset.field_mime', 'Type MIME'),
    ('fr', 'asset.field_title', 'Titre'),
    ('fr', 'asset.field_description', 'Description'),
    ('fr', 'asset.field_filename', 'Fichier'),
    ('fr', 'asset.field_dimensions', 'Dimensions'),
    ('fr', 'asset.field_credit', 'Crédit'),
    ('fr', 'asset.field_saison', 'Saison'),
    ('fr', 'asset.field_usage_hint', 'Usage recommandé'),
    ('fr', 'asset.field_colors', 'Couleurs dominantes'),
    ('fr', 'asset.field_orientation', 'Orientation'),
    ('fr', 'asset.field_created', 'Créé le'),
    ('fr', 'asset.field_classified', 'Classifié le'),
    ('fr', 'asset.field_path', 'Chemin'),

    -- Common
    ('fr', 'asset.filter_all', 'Tous'),
    ('fr', 'asset.btn_filter', 'Filtrer'),
    ('fr', 'asset.btn_delete', 'Supprimer'),
    ('fr', 'asset.btn_classify', 'Classifier'),
    ('fr', 'asset.btn_archive', 'Archiver'),
    ('fr', 'asset.btn_restore', 'Restaurer'),
    ('fr', 'asset.btn_edit', 'Modifier'),

    -- Table headers
    ('fr', 'asset.col_filename', 'Fichier'),
    ('fr', 'asset.col_title', 'Titre'),
    ('fr', 'asset.col_mime', 'Type'),
    ('fr', 'asset.col_status', 'Statut'),
    ('fr', 'asset.col_tags', 'Tags'),
    ('fr', 'asset.col_created', 'Créé le'),

    -- Stats
    ('fr', 'asset.stat_total', 'Total assets'),
    ('fr', 'asset.stat_to_classify', 'À classifier'),
    ('fr', 'asset.stat_classified', 'Classifiés'),

    -- Sections (form)
    ('fr', 'asset.section_file', 'Fichier'),
    ('fr', 'asset.section_metadata', 'Métadonnées'),
    ('fr', 'asset.section_classification', 'Classification'),

    -- Empty states
    ('fr', 'asset.empty_no_asset', 'Aucun asset'),
    ('fr', 'asset.empty_first_asset', 'Les assets apparaîtront ici après upload dans Supabase Storage.'),
    ('fr', 'asset.empty_no_results', 'Aucun résultat pour ces filtres.'),

    -- Toast / errors
    ('fr', 'asset.toast_classified', 'Asset classifié.'),
    ('fr', 'asset.toast_deleted', 'Asset supprimé.'),
    ('fr', 'asset.toast_archived', 'Asset archivé.'),
    ('fr', 'asset.toast_restored', 'Asset restauré.'),
    ('fr', 'asset.err_not_found', 'Asset introuvable.'),
    ('fr', 'asset.err_title_required', 'Le titre est obligatoire.'),

    -- Confirm
    ('fr', 'asset.confirm_delete', 'Supprimer définitivement cet asset ?'),
    ('fr', 'asset.confirm_archive', 'Archiver cet asset ?'),

    -- Actions
    ('fr', 'asset.action_classify', 'Classifier'),
    ('fr', 'asset.action_archive', 'Archiver'),
    ('fr', 'asset.action_restore', 'Restaurer'),
    ('fr', 'asset.action_delete', 'Supprimer'),
    ('fr', 'asset.action_edit', 'Modifier'),

    -- Saison options
    ('fr', 'asset.saison_printemps', 'Printemps'),
    ('fr', 'asset.saison_ete', 'Été'),
    ('fr', 'asset.saison_automne', 'Automne'),
    ('fr', 'asset.saison_hiver', 'Hiver')

  ON CONFLICT DO NOTHING;
END;
$function$;
