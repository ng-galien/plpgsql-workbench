CREATE OR REPLACE FUNCTION stock.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Delete old French keys that were renamed
  DELETE FROM pgv.i18n WHERE lang = 'fr' AND key IN (
    'stock.nav_depots', 'stock.nav_mouvements', 'stock.nav_alertes', 'stock.nav_valorisation', 'stock.nav_inventaire',
    'stock.entity_depot',
    'stock.field_designation', 'stock.field_categorie', 'stock.field_unite', 'stock.field_prix_achat',
    'stock.field_seuil_mini', 'stock.field_fournisseur', 'stock.field_article_catalog',
    'stock.field_nom', 'stock.field_adresse', 'stock.field_quantite', 'stock.field_prix_unitaire',
    'stock.field_depot_dest', 'stock.field_ref_doc', 'stock.field_actif',
    'stock.stat_seuil_mini', 'stock.stat_fournisseur', 'stock.stat_valeur_stock', 'stock.stat_mvt_semaine',
    'stock.stat_valeur_totale', 'stock.stat_articles_stock', 'stock.stat_en_alerte',
    'stock.rel_fournisseur',
    'stock.categorie_options', 'stock.unite_options', 'stock.depot_type_options',
    'stock.type_entree', 'stock.type_sortie', 'stock.type_transfert', 'stock.type_inventaire',
    'stock.cat_bois', 'stock.cat_quincaillerie', 'stock.cat_panneau', 'stock.cat_isolant', 'stock.cat_finition', 'stock.cat_autre',
    'stock.depot_atelier', 'stock.depot_chantier', 'stock.depot_vehicule', 'stock.depot_entrepot',
    'stock.col_designation', 'stock.col_categorie', 'stock.col_fournisseur', 'stock.col_actif',
    'stock.col_adresse', 'stock.col_depot', 'stock.col_quantite', 'stock.col_stock_actuel',
    'stock.col_seuil', 'stock.col_statut', 'stock.col_mouvements', 'stock.col_qty_totale',
    'stock.col_theorique', 'stock.col_reel', 'stock.col_valeur', 'stock.col_unite',
    'stock.title_stock_bas', 'stock.title_top_articles', 'stock.title_derniers_mvt',
    'stock.title_stock_depot', 'stock.title_mvt_recents', 'stock.title_contenu',
    'stock.title_par_depot', 'stock.title_par_categorie', 'stock.title_select_depot', 'stock.title_infos',
    'stock.btn_nouveau_mvt', 'stock.btn_nouvel_article', 'stock.btn_nouveau_depot',
    'stock.btn_modifier', 'stock.btn_creer', 'stock.btn_enregistrer', 'stock.btn_valider_inventaire',
    'stock.btn_desactiver',
    'stock.confirm_desactiver',
    'stock.empty_no_mouvement', 'stock.empty_first_mouvement', 'stock.empty_no_depot',
    'stock.empty_first_depot', 'stock.empty_depot_not_found', 'stock.empty_depot_vide',
    'stock.empty_no_alerte', 'stock.empty_all_above', 'stock.empty_depot_create_first',
    'stock.empty_depot_inactive', 'stock.empty_no_article_actif', 'stock.empty_first_mouvement_short',
    'stock.err_depot_dest_requis', 'stock.err_depot_src_dest_identiques',
    'stock.err_stock_insuffisant', 'stock.err_stock_insuffisant_transfert',
    'stock.err_depot_not_found', 'stock.err_depot_inactive', 'stock.err_no_lignes',
    'stock.toast_article_modifie', 'stock.toast_article_cree', 'stock.toast_article_desactive',
    'stock.toast_depot_modifie', 'stock.toast_depot_cree', 'stock.toast_mvt_enregistre',
    'stock.toast_stock_correct', 'stock.toast_stock_conforme', 'stock.toast_inventaire_valide',
    'stock.label_ref', 'stock.label_categorie', 'stock.label_actif', 'stock.label_catalog',
    'stock.label_type', 'stock.label_adresse',
    'stock.ph_categorie', 'stock.ph_type', 'stock.ph_depot', 'stock.ph_aucun',
    'stock.ph_ref_doc', 'stock.ph_search_article', 'stock.ph_search_catalog',
    'stock.cross_catalog_voir', 'stock.cross_catalog_unavailable',
    'stock.rel_movements', 'stock.rel_catalog',
    'stock.yes', 'stock.no'
  );

  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'stock.brand', 'Stock'),
    ('fr', 'stock.nav_articles', 'Articles'),
    ('fr', 'stock.nav_warehouses', 'Dépôts'),
    ('fr', 'stock.nav_movements', 'Mouvements'),
    ('fr', 'stock.nav_alerts', 'Alertes'),
    ('fr', 'stock.nav_valuation', 'Valorisation'),
    ('fr', 'stock.nav_inventory', 'Inventaire'),

    -- Entity labels
    ('fr', 'stock.entity_article', 'Article'),
    ('fr', 'stock.entity_warehouse', 'Dépôt'),

    -- Movement types
    ('fr', 'stock.type_entry', 'Entrée'),
    ('fr', 'stock.type_exit', 'Sortie'),
    ('fr', 'stock.type_transfer', 'Transfert'),
    ('fr', 'stock.type_inventory', 'Inventaire'),

    -- Category labels
    ('fr', 'stock.cat_wood', 'Bois'),
    ('fr', 'stock.cat_hardware', 'Quincaillerie'),
    ('fr', 'stock.cat_panel', 'Panneau'),
    ('fr', 'stock.cat_insulation', 'Isolant'),
    ('fr', 'stock.cat_finishing', 'Finition'),
    ('fr', 'stock.cat_other', 'Autre'),

    -- Unit labels
    ('fr', 'stock.unit_u', 'Unité'),
    ('fr', 'stock.unit_m', 'Mètre'),
    ('fr', 'stock.unit_m2', 'm²'),
    ('fr', 'stock.unit_m3', 'm³'),
    ('fr', 'stock.unit_kg', 'kg'),
    ('fr', 'stock.unit_l', 'Litre'),

    -- Warehouse type labels
    ('fr', 'stock.warehouse_workshop', 'Atelier'),
    ('fr', 'stock.warehouse_site', 'Chantier'),
    ('fr', 'stock.warehouse_vehicle', 'Véhicule'),
    ('fr', 'stock.warehouse_storage', 'Entrepôt'),

    -- Field labels
    ('fr', 'stock.field_reference', 'Référence'),
    ('fr', 'stock.field_description', 'Désignation'),
    ('fr', 'stock.field_category', 'Catégorie'),
    ('fr', 'stock.field_unit', 'Unité'),
    ('fr', 'stock.field_purchase_price', 'Prix d''achat'),
    ('fr', 'stock.field_min_threshold', 'Seuil mini'),
    ('fr', 'stock.field_supplier', 'Fournisseur'),
    ('fr', 'stock.field_notes', 'Notes'),
    ('fr', 'stock.field_name', 'Nom'),
    ('fr', 'stock.field_type', 'Type'),
    ('fr', 'stock.field_address', 'Adresse'),
    ('fr', 'stock.field_quantity', 'Quantité'),
    ('fr', 'stock.field_unit_price', 'Prix unitaire'),
    ('fr', 'stock.field_dest_warehouse', 'Dépôt destination (transfert)'),
    ('fr', 'stock.field_doc_ref', 'Référence doc'),
    ('fr', 'stock.field_catalog_article', 'Article catalog'),
    ('fr', 'stock.field_active', 'Actif'),

    -- Placeholders
    ('fr', 'stock.ph_category', '-- Catégorie --'),
    ('fr', 'stock.ph_type', '-- Type --'),
    ('fr', 'stock.ph_warehouse', '-- Dépôt --'),
    ('fr', 'stock.ph_none', '-- Aucun --'),
    ('fr', 'stock.ph_doc_ref', 'N° BL, commande...'),
    ('fr', 'stock.ph_search_article', 'Rechercher un article...'),
    ('fr', 'stock.ph_search_catalog', 'Rechercher un article catalog...'),

    -- Table column headers
    ('fr', 'stock.col_ref', 'Réf.'),
    ('fr', 'stock.col_description', 'Désignation'),
    ('fr', 'stock.col_category', 'Catégorie'),
    ('fr', 'stock.col_stock', 'Stock'),
    ('fr', 'stock.col_pmp', 'PMP'),
    ('fr', 'stock.col_alert', 'Alerte'),
    ('fr', 'stock.col_supplier', 'Fournisseur'),
    ('fr', 'stock.col_active', 'Actif'),
    ('fr', 'stock.col_name', 'Nom'),
    ('fr', 'stock.col_type', 'Type'),
    ('fr', 'stock.col_address', 'Adresse'),
    ('fr', 'stock.col_articles', 'Articles'),
    ('fr', 'stock.col_date', 'Date'),
    ('fr', 'stock.col_article', 'Article'),
    ('fr', 'stock.col_warehouse', 'Dépôt'),
    ('fr', 'stock.col_qty', 'Qté'),
    ('fr', 'stock.col_doc_ref', 'Réf. doc'),
    ('fr', 'stock.col_quantity', 'Quantité'),
    ('fr', 'stock.col_current_stock', 'Stock actuel'),
    ('fr', 'stock.col_threshold', 'Seuil'),
    ('fr', 'stock.col_status', 'Statut'),
    ('fr', 'stock.col_unit_price', 'PU'),
    ('fr', 'stock.col_movements', 'Mouvements'),
    ('fr', 'stock.col_total_qty', 'Qté totale'),
    ('fr', 'stock.col_theoretical', 'Théorique'),
    ('fr', 'stock.col_actual', 'Réel'),
    ('fr', 'stock.col_value', 'Valeur'),
    ('fr', 'stock.col_unit', 'Unité'),

    -- Stats
    ('fr', 'stock.stat_articles', 'Articles'),
    ('fr', 'stock.stat_stock_value', 'Valeur stock'),
    ('fr', 'stock.stat_alerts', 'Alertes'),
    ('fr', 'stock.stat_week_movements', 'Mouvements semaine'),
    ('fr', 'stock.stat_stock_total', 'Stock total'),
    ('fr', 'stock.stat_pmp', 'PMP'),
    ('fr', 'stock.stat_min_threshold', 'Seuil mini'),
    ('fr', 'stock.stat_supplier', 'Fournisseur'),
    ('fr', 'stock.stat_total_value', 'Valeur totale'),
    ('fr', 'stock.stat_in_stock', 'Articles en stock'),
    ('fr', 'stock.stat_in_alert', 'En alerte'),
    ('fr', 'stock.stat_nb_articles', 'Nb articles'),

    -- Section titles
    ('fr', 'stock.title_low_stock', 'Stock bas'),
    ('fr', 'stock.title_top_articles', 'Top articles ce mois'),
    ('fr', 'stock.title_recent_movements', 'Derniers mouvements'),
    ('fr', 'stock.title_stock_by_warehouse', 'Stock par dépôt'),
    ('fr', 'stock.title_recent_mvt', 'Mouvements récents'),
    ('fr', 'stock.title_content', 'Contenu'),
    ('fr', 'stock.title_by_warehouse', 'Par dépôt'),
    ('fr', 'stock.title_by_category', 'Par catégorie'),
    ('fr', 'stock.title_select_warehouse', 'Sélectionnez le dépôt à inventorier :'),
    ('fr', 'stock.title_info', 'Informations'),
    ('fr', 'stock.section_identity', 'Identification'),
    ('fr', 'stock.section_pricing', 'Tarification & seuils'),
    ('fr', 'stock.section_links', 'Liens'),
    ('fr', 'stock.section_location', 'Localisation'),

    -- Buttons / Actions
    ('fr', 'stock.btn_new_movement', 'Nouveau mouvement'),
    ('fr', 'stock.btn_new_article', 'Nouvel article'),
    ('fr', 'stock.btn_new_warehouse', 'Nouveau dépôt'),
    ('fr', 'stock.btn_edit', 'Modifier'),
    ('fr', 'stock.btn_create', 'Créer'),
    ('fr', 'stock.btn_save', 'Enregistrer'),
    ('fr', 'stock.btn_validate_inventory', 'Valider l''inventaire'),
    ('fr', 'stock.btn_deactivate', 'Désactiver'),
    ('fr', 'stock.action_deactivate', 'Désactiver'),
    ('fr', 'stock.action_activate', 'Réactiver'),
    ('fr', 'stock.action_delete', 'Supprimer'),
    ('fr', 'stock.action_new_movement', 'Nouveau mouvement'),
    ('fr', 'stock.action_inventory', 'Inventaire'),
    ('fr', 'stock.confirm_deactivate', 'Désactiver cet élément ?'),
    ('fr', 'stock.confirm_delete', 'Supprimer définitivement ?'),

    -- Empty states
    ('fr', 'stock.empty_no_movement', 'Aucun mouvement'),
    ('fr', 'stock.empty_first_movement', 'Enregistrez votre premier mouvement de stock.'),
    ('fr', 'stock.empty_no_article', 'Aucun article'),
    ('fr', 'stock.empty_first_article', 'Créez votre premier article pour commencer.'),
    ('fr', 'stock.empty_no_warehouse', 'Aucun dépôt'),
    ('fr', 'stock.empty_first_warehouse', 'Créez votre premier dépôt pour commencer.'),
    ('fr', 'stock.empty_article_not_found', 'Article introuvable'),
    ('fr', 'stock.empty_warehouse_not_found', 'Dépôt introuvable'),
    ('fr', 'stock.empty_warehouse_empty', 'Dépôt vide'),
    ('fr', 'stock.empty_no_alert', 'Aucune alerte'),
    ('fr', 'stock.empty_all_above_threshold', 'Tous les articles sont au-dessus du seuil minimum.'),
    ('fr', 'stock.empty_create_warehouse_first', 'Créez un dépôt avant de faire un inventaire.'),
    ('fr', 'stock.empty_warehouse_inactive', 'Ce dépôt n''existe pas ou est inactif.'),
    ('fr', 'stock.empty_no_active_article', 'Aucun article actif dans le catalogue.'),
    ('fr', 'stock.empty_first_movement_short', 'Enregistrez votre premier mouvement.'),

    -- Error messages
    ('fr', 'stock.err_article_not_found', 'Article introuvable'),
    ('fr', 'stock.err_dest_warehouse_required', 'Dépôt destination requis pour un transfert'),
    ('fr', 'stock.err_same_src_dest', 'Dépôt source et destination identiques'),
    ('fr', 'stock.err_insufficient_stock', 'Stock insuffisant dans ce dépôt'),
    ('fr', 'stock.err_insufficient_stock_transfer', 'Stock insuffisant pour le transfert'),
    ('fr', 'stock.err_warehouse_not_found', 'Dépôt introuvable'),
    ('fr', 'stock.err_warehouse_inactive', 'Dépôt inexistant ou inactif'),
    ('fr', 'stock.err_no_lines', 'Aucune ligne à réceptionner'),

    -- Toast messages
    ('fr', 'stock.toast_article_updated', 'Article modifié'),
    ('fr', 'stock.toast_article_created', 'Article créé'),
    ('fr', 'stock.toast_article_deactivated', 'Article désactivé'),
    ('fr', 'stock.toast_warehouse_updated', 'Dépôt modifié'),
    ('fr', 'stock.toast_warehouse_created', 'Dépôt créé'),
    ('fr', 'stock.toast_movement_recorded', 'Mouvement enregistré'),
    ('fr', 'stock.toast_stock_correct', 'Stock déjà correct, aucun ajustement'),
    ('fr', 'stock.toast_stock_compliant', 'Stock conforme — aucun ajustement'),
    ('fr', 'stock.toast_inventory_validated', 'Inventaire validé — %s ajustement(s)'),

    -- Info labels
    ('fr', 'stock.label_ref', 'Réf:'),
    ('fr', 'stock.label_category', 'Catégorie:'),
    ('fr', 'stock.label_active', 'Actif:'),
    ('fr', 'stock.label_catalog', 'Catalog:'),
    ('fr', 'stock.label_type', 'Type:'),
    ('fr', 'stock.label_address', 'Adresse:'),

    -- Cross-module
    ('fr', 'stock.cross_catalog_view', 'Voir fiche catalog'),
    ('fr', 'stock.cross_catalog_unavailable', 'catalog non disponible'),

    -- _view() related
    ('fr', 'stock.rel_movements', 'Mouvements'),
    ('fr', 'stock.rel_supplier', 'Fournisseur'),
    ('fr', 'stock.rel_catalog', 'Article catalog'),
    ('fr', 'stock.rel_articles', 'Articles en stock'),

    -- Options keys
    ('fr', 'stock.category_options', 'Options catégorie'),
    ('fr', 'stock.unit_options', 'Options unité'),
    ('fr', 'stock.warehouse_type_options', 'Options type dépôt')

  ON CONFLICT DO NOTHING;
END;
$function$;
