CREATE OR REPLACE FUNCTION asset.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'asset.brand', 'Assets'),
    ('fr', 'asset.nav_assets', 'Bibliothèque'),

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
    ('fr', 'asset.field_credit', 'Crédit'),
    ('fr', 'asset.field_saison', 'Saison'),
    ('fr', 'asset.field_usage_hint', 'Usage recommandé'),
    ('fr', 'asset.field_colors', 'Couleurs dominantes'),
    ('fr', 'asset.field_width', 'Largeur'),
    ('fr', 'asset.field_height', 'Hauteur'),
    ('fr', 'asset.field_orientation', 'Orientation'),

    -- Common
    ('fr', 'asset.filter_all', 'Tous'),
    ('fr', 'asset.btn_filter', 'Filtrer'),

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

    -- Empty states
    ('fr', 'asset.empty_no_asset', 'Aucun asset'),
    ('fr', 'asset.empty_first_asset', 'Les assets apparaîtront ici après upload dans Supabase Storage.'),
    ('fr', 'asset.empty_no_results', 'Aucun résultat pour ces filtres.'),

    -- Toast / errors
    ('fr', 'asset.toast_classified', 'Asset classifié.'),
    ('fr', 'asset.err_not_found', 'Asset introuvable.'),
    ('fr', 'asset.err_title_required', 'Le titre est obligatoire.')

  ON CONFLICT DO NOTHING;
END;
$function$;
