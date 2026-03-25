CREATE OR REPLACE FUNCTION catalog.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'catalog.brand', 'Catalogue'),
    ('fr', 'catalog.nav_articles', 'Articles'),
    ('fr', 'catalog.nav_categories', 'Catégories'),

    -- Entity labels
    ('fr', 'catalog.entity_article', 'Article'),
    ('fr', 'catalog.entity_categorie', 'Catégorie'),

    -- Stats
    ('fr', 'catalog.stat_articles_actifs', 'Articles actifs'),
    ('fr', 'catalog.stat_categories', 'Catégories'),
    ('fr', 'catalog.stat_prix_moyen', 'Prix moyen vente'),

    -- Field labels
    ('fr', 'catalog.field_reference', 'Référence'),
    ('fr', 'catalog.field_designation', 'Désignation'),
    ('fr', 'catalog.field_categorie', 'Catégorie'),
    ('fr', 'catalog.field_description', 'Description'),
    ('fr', 'catalog.field_unite', 'Unité'),
    ('fr', 'catalog.field_tva', 'TVA'),
    ('fr', 'catalog.field_prix_vente', 'Prix vente HT'),
    ('fr', 'catalog.field_prix_achat', 'Prix achat HT'),
    ('fr', 'catalog.field_statut', 'Statut'),
    ('fr', 'catalog.field_search', 'Recherche'),
    ('fr', 'catalog.field_categorie_placeholder', '-- Catégorie --'),
    ('fr', 'catalog.field_categorie_parente', 'Catégorie parente'),
    ('fr', 'catalog.field_categorie_parente_placeholder', '-- Aucune (racine) --'),
    ('fr', 'catalog.field_nom', 'Nom'),
    ('fr', 'catalog.field_ordre', 'Ordre'),
    ('fr', 'catalog.field_actif', 'Actif'),

    -- Table headers
    ('fr', 'catalog.col_ref', 'Réf.'),
    ('fr', 'catalog.col_designation', 'Désignation'),
    ('fr', 'catalog.col_categorie', 'Catégorie'),
    ('fr', 'catalog.col_pv_ht', 'PV HT'),
    ('fr', 'catalog.col_pa_ht', 'PA HT'),
    ('fr', 'catalog.col_prix_vente', 'Prix vente'),
    ('fr', 'catalog.col_unite', 'Unité'),
    ('fr', 'catalog.col_tva', 'TVA'),
    ('fr', 'catalog.col_statut', 'Statut'),
    ('fr', 'catalog.col_nom', 'Nom'),
    ('fr', 'catalog.col_parente', 'Parente'),
    ('fr', 'catalog.col_articles', 'Articles'),
    ('fr', 'catalog.col_voir', 'Voir'),

    -- Detail labels
    ('fr', 'catalog.detail_created_at', 'Créé le'),
    ('fr', 'catalog.detail_updated_at', 'Modifié le'),

    -- Values / badges
    ('fr', 'catalog.badge_actif', 'Actif'),
    ('fr', 'catalog.badge_inactif', 'Inactif'),

    -- Filters
    ('fr', 'catalog.filter_all_categories', 'Toutes catégories'),
    ('fr', 'catalog.filter_all', 'Tous'),
    ('fr', 'catalog.filter_actifs', 'Actifs'),
    ('fr', 'catalog.filter_inactifs', 'Inactifs'),

    -- Buttons / Actions
    ('fr', 'catalog.btn_filter', 'Filtrer'),
    ('fr', 'catalog.btn_new_article', 'Nouvel article'),
    ('fr', 'catalog.btn_modifier', 'Modifier'),
    ('fr', 'catalog.btn_creer', 'Créer'),
    ('fr', 'catalog.btn_desactiver', 'Désactiver'),
    ('fr', 'catalog.btn_reactiver', 'Réactiver'),

    -- _view() actions
    ('fr', 'catalog.action_deactivate', 'Désactiver'),
    ('fr', 'catalog.action_activate', 'Réactiver'),
    ('fr', 'catalog.action_delete', 'Supprimer'),
    ('fr', 'catalog.confirm_deactivate', 'Désactiver cet article ?'),
    ('fr', 'catalog.confirm_delete', 'Supprimer définitivement ?'),

    -- _view() form sections
    ('fr', 'catalog.section_identity', 'Identité'),
    ('fr', 'catalog.section_pricing', 'Tarification'),
    ('fr', 'catalog.section_classification', 'Classification'),

    -- _view() related
    ('fr', 'catalog.related_quotes', 'Devis'),
    ('fr', 'catalog.related_stock', 'Stock'),
    ('fr', 'catalog.related_purchases', 'Commandes fournisseur'),

    -- Titles
    ('fr', 'catalog.title_recent', 'Articles récents'),
    ('fr', 'catalog.title_new_categorie', 'Nouvelle catégorie'),

    -- Empty states
    ('fr', 'catalog.empty_no_article', 'Aucun article'),
    ('fr', 'catalog.empty_first_article', 'Créez votre premier article pour commencer.'),
    ('fr', 'catalog.empty_no_article_found', 'Aucun article trouvé'),
    ('fr', 'catalog.empty_adjust_filters', 'Modifiez vos filtres ou créez un article.'),
    ('fr', 'catalog.empty_no_categorie', 'Aucune catégorie'),
    ('fr', 'catalog.empty_first_categorie', 'Créez votre première catégorie.'),

    -- Error messages
    ('fr', 'catalog.err_not_found', 'Article introuvable'),
    ('fr', 'catalog.err_id_missing', 'ID article manquant'),

    -- Toast messages
    ('fr', 'catalog.toast_article_created', 'Article créé'),
    ('fr', 'catalog.toast_article_modified', 'Article modifié'),
    ('fr', 'catalog.toast_categorie_created', 'Catégorie créée'),

    -- Confirm dialogs (legacy)
    ('fr', 'catalog.confirm_desactiver', 'Désactiver cet article ?')

  ON CONFLICT DO NOTHING;
END;
$function$;
