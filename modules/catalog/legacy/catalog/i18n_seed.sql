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
    ('fr', 'catalog.entity_category', 'Catégorie'),

    -- Stats
    ('fr', 'catalog.stat_active_articles', 'Articles actifs'),
    ('fr', 'catalog.stat_categories', 'Catégories'),
    ('fr', 'catalog.stat_avg_sale_price', 'Prix moyen vente'),

    -- Field labels
    ('fr', 'catalog.field_reference', 'Référence'),
    ('fr', 'catalog.field_name', 'Nom'),
    ('fr', 'catalog.field_category', 'Catégorie'),
    ('fr', 'catalog.field_description', 'Description'),
    ('fr', 'catalog.field_unit', 'Unité'),
    ('fr', 'catalog.field_vat_rate', 'TVA'),
    ('fr', 'catalog.field_sale_price', 'Prix vente HT'),
    ('fr', 'catalog.field_purchase_price', 'Prix achat HT'),
    ('fr', 'catalog.field_status', 'Statut'),
    ('fr', 'catalog.field_search', 'Recherche'),
    ('fr', 'catalog.field_parent_category', 'Catégorie parente'),
    ('fr', 'catalog.field_sort_order', 'Ordre'),
    ('fr', 'catalog.field_active', 'Actif'),

    -- Table headers
    ('fr', 'catalog.col_ref', 'Réf.'),
    ('fr', 'catalog.col_name', 'Nom'),
    ('fr', 'catalog.col_category', 'Catégorie'),
    ('fr', 'catalog.col_sale_price', 'PV HT'),
    ('fr', 'catalog.col_purchase_price', 'PA HT'),
    ('fr', 'catalog.col_unit', 'Unité'),
    ('fr', 'catalog.col_vat_rate', 'TVA'),
    ('fr', 'catalog.col_status', 'Statut'),
    ('fr', 'catalog.col_parent', 'Parente'),
    ('fr', 'catalog.col_articles', 'Articles'),

    -- Detail labels
    ('fr', 'catalog.detail_created_at', 'Créé le'),
    ('fr', 'catalog.detail_updated_at', 'Modifié le'),

    -- Badges
    ('fr', 'catalog.badge_active', 'Actif'),
    ('fr', 'catalog.badge_inactive', 'Inactif'),

    -- Filters
    ('fr', 'catalog.filter_all_categories', 'Toutes catégories'),
    ('fr', 'catalog.filter_all', 'Tous'),
    ('fr', 'catalog.filter_active', 'Actifs'),
    ('fr', 'catalog.filter_inactive', 'Inactifs'),

    -- Buttons
    ('fr', 'catalog.btn_filter', 'Filtrer'),
    ('fr', 'catalog.btn_new_article', 'Nouvel article'),
    ('fr', 'catalog.btn_edit', 'Modifier'),
    ('fr', 'catalog.btn_create', 'Créer'),

    -- Actions
    ('fr', 'catalog.action_deactivate', 'Désactiver'),
    ('fr', 'catalog.action_activate', 'Réactiver'),
    ('fr', 'catalog.action_delete', 'Supprimer'),
    ('fr', 'catalog.confirm_deactivate', 'Désactiver cet article ?'),
    ('fr', 'catalog.confirm_delete', 'Supprimer définitivement ?'),

    -- Form sections
    ('fr', 'catalog.section_identity', 'Identité'),
    ('fr', 'catalog.section_pricing', 'Tarification'),
    ('fr', 'catalog.section_classification', 'Classification'),

    -- Related
    ('fr', 'catalog.related_quotes', 'Devis'),
    ('fr', 'catalog.related_stock', 'Stock'),
    ('fr', 'catalog.related_purchases', 'Commandes fournisseur'),

    -- Titles
    ('fr', 'catalog.title_recent', 'Articles récents'),
    ('fr', 'catalog.title_new_category', 'Nouvelle catégorie'),

    -- Empty states
    ('fr', 'catalog.empty_no_article', 'Aucun article'),
    ('fr', 'catalog.empty_first_article', 'Créez votre premier article pour commencer.'),
    ('fr', 'catalog.empty_no_article_found', 'Aucun article trouvé'),
    ('fr', 'catalog.empty_adjust_filters', 'Modifiez vos filtres ou créez un article.'),
    ('fr', 'catalog.empty_no_category', 'Aucune catégorie'),
    ('fr', 'catalog.empty_first_category', 'Créez votre première catégorie.'),

    -- Errors / toasts
    ('fr', 'catalog.err_not_found', 'Article introuvable'),
    ('fr', 'catalog.err_id_missing', 'ID article manquant'),
    ('fr', 'catalog.toast_article_created', 'Article créé'),
    ('fr', 'catalog.toast_article_updated', 'Article modifié'),
    ('fr', 'catalog.toast_category_created', 'Catégorie créée')

  ON CONFLICT DO NOTHING;
END;
$function$;
