CREATE OR REPLACE FUNCTION stock.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'stock.brand', 'Stock'),
    ('fr', 'stock.nav_articles', 'Articles'),
    ('fr', 'stock.nav_depots', 'Dépôts'),
    ('fr', 'stock.nav_mouvements', 'Mouvements'),
    ('fr', 'stock.nav_alertes', 'Alertes'),
    ('fr', 'stock.nav_valorisation', 'Valorisation'),
    ('fr', 'stock.nav_inventaire', 'Inventaire'),

    -- Movement types
    ('fr', 'stock.type_entree', 'Entrée'),
    ('fr', 'stock.type_sortie', 'Sortie'),
    ('fr', 'stock.type_transfert', 'Transfert'),
    ('fr', 'stock.type_inventaire', 'Inventaire'),

    -- Category labels
    ('fr', 'stock.cat_bois', 'Bois'),
    ('fr', 'stock.cat_quincaillerie', 'Quincaillerie'),
    ('fr', 'stock.cat_panneau', 'Panneau'),
    ('fr', 'stock.cat_isolant', 'Isolant'),
    ('fr', 'stock.cat_finition', 'Finition'),
    ('fr', 'stock.cat_autre', 'Autre'),

    -- Unit labels
    ('fr', 'stock.unit_u', 'Unité'),
    ('fr', 'stock.unit_m', 'Mètre'),
    ('fr', 'stock.unit_m2', 'm²'),
    ('fr', 'stock.unit_m3', 'm³'),
    ('fr', 'stock.unit_kg', 'kg'),
    ('fr', 'stock.unit_l', 'Litre'),

    -- Depot type labels
    ('fr', 'stock.depot_atelier', 'Atelier'),
    ('fr', 'stock.depot_chantier', 'Chantier'),
    ('fr', 'stock.depot_vehicule', 'Véhicule'),
    ('fr', 'stock.depot_entrepot', 'Entrepôt'),

    -- Field labels
    ('fr', 'stock.field_reference', 'Référence'),
    ('fr', 'stock.field_designation', 'Désignation'),
    ('fr', 'stock.field_categorie', 'Catégorie'),
    ('fr', 'stock.field_unite', 'Unité'),
    ('fr', 'stock.field_prix_achat', 'Prix d''achat'),
    ('fr', 'stock.field_seuil_mini', 'Seuil mini'),
    ('fr', 'stock.field_fournisseur', 'Fournisseur'),
    ('fr', 'stock.field_notes', 'Notes'),
    ('fr', 'stock.field_nom', 'Nom'),
    ('fr', 'stock.field_type', 'Type'),
    ('fr', 'stock.field_adresse', 'Adresse'),
    ('fr', 'stock.field_quantite', 'Quantité'),
    ('fr', 'stock.field_prix_unitaire', 'Prix unitaire'),
    ('fr', 'stock.field_depot_dest', 'Dépôt destination (transfert)'),
    ('fr', 'stock.field_ref_doc', 'Référence doc'),
    ('fr', 'stock.field_article_catalog', 'Article catalog'),
    ('fr', 'stock.field_actif', 'Actif'),

    -- Common values
    ('fr', 'stock.yes', 'Oui'),
    ('fr', 'stock.no', 'Non'),

    -- Placeholders
    ('fr', 'stock.ph_categorie', '-- Catégorie --'),
    ('fr', 'stock.ph_type', '-- Type --'),
    ('fr', 'stock.ph_depot', '-- Dépôt --'),
    ('fr', 'stock.ph_aucun', '-- Aucun --'),
    ('fr', 'stock.ph_ref_doc', 'N° BL, commande...'),
    ('fr', 'stock.ph_search_article', 'Rechercher un article...'),
    ('fr', 'stock.ph_search_catalog', 'Rechercher un article catalog...'),

    -- Table column headers
    ('fr', 'stock.col_ref', 'Réf.'),
    ('fr', 'stock.col_designation', 'Désignation'),
    ('fr', 'stock.col_categorie', 'Catégorie'),
    ('fr', 'stock.col_stock', 'Stock'),
    ('fr', 'stock.col_pmp', 'PMP'),
    ('fr', 'stock.col_alerte', 'Alerte'),
    ('fr', 'stock.col_fournisseur', 'Fournisseur'),
    ('fr', 'stock.col_actif', 'Actif'),
    ('fr', 'stock.col_nom', 'Nom'),
    ('fr', 'stock.col_type', 'Type'),
    ('fr', 'stock.col_adresse', 'Adresse'),
    ('fr', 'stock.col_articles', 'Articles'),
    ('fr', 'stock.col_date', 'Date'),
    ('fr', 'stock.col_article', 'Article'),
    ('fr', 'stock.col_depot', 'Dépôt'),
    ('fr', 'stock.col_qty', 'Qté'),
    ('fr', 'stock.col_ref_doc', 'Réf. doc'),
    ('fr', 'stock.col_quantite', 'Quantité'),
    ('fr', 'stock.col_stock_actuel', 'Stock actuel'),
    ('fr', 'stock.col_seuil', 'Seuil'),
    ('fr', 'stock.col_statut', 'Statut'),
    ('fr', 'stock.col_pu', 'PU'),
    ('fr', 'stock.col_mouvements', 'Mouvements'),
    ('fr', 'stock.col_qty_totale', 'Qté totale'),
    ('fr', 'stock.col_theorique', 'Théorique'),
    ('fr', 'stock.col_reel', 'Réel'),
    ('fr', 'stock.col_valeur', 'Valeur'),
    ('fr', 'stock.col_unite', 'Unité'),

    -- Stats
    ('fr', 'stock.stat_articles', 'Articles'),
    ('fr', 'stock.stat_valeur_stock', 'Valeur stock'),
    ('fr', 'stock.stat_alertes', 'Alertes'),
    ('fr', 'stock.stat_mvt_semaine', 'Mouvements semaine'),
    ('fr', 'stock.stat_stock_total', 'Stock total'),
    ('fr', 'stock.stat_pmp', 'PMP'),
    ('fr', 'stock.stat_seuil_mini', 'Seuil mini'),
    ('fr', 'stock.stat_fournisseur', 'Fournisseur'),
    ('fr', 'stock.stat_valeur_totale', 'Valeur totale'),
    ('fr', 'stock.stat_articles_stock', 'Articles en stock'),
    ('fr', 'stock.stat_en_alerte', 'En alerte'),

    -- Section titles
    ('fr', 'stock.title_stock_bas', 'Stock bas'),
    ('fr', 'stock.title_top_articles', 'Top articles ce mois'),
    ('fr', 'stock.title_derniers_mvt', 'Derniers mouvements'),
    ('fr', 'stock.title_stock_depot', 'Stock par dépôt'),
    ('fr', 'stock.title_mvt_recents', 'Mouvements récents'),
    ('fr', 'stock.title_contenu', 'Contenu'),
    ('fr', 'stock.title_par_depot', 'Par dépôt'),
    ('fr', 'stock.title_par_categorie', 'Par catégorie'),
    ('fr', 'stock.title_select_depot', 'Sélectionnez le dépôt à inventorier :'),

    -- Buttons / Actions
    ('fr', 'stock.btn_nouveau_mvt', 'Nouveau mouvement'),
    ('fr', 'stock.btn_nouvel_article', 'Nouvel article'),
    ('fr', 'stock.btn_nouveau_depot', 'Nouveau dépôt'),
    ('fr', 'stock.btn_modifier', 'Modifier'),
    ('fr', 'stock.btn_creer', 'Créer'),
    ('fr', 'stock.btn_enregistrer', 'Enregistrer'),
    ('fr', 'stock.btn_valider_inventaire', 'Valider l''inventaire'),
    ('fr', 'stock.btn_desactiver', 'Désactiver'),

    -- Confirm dialogs
    ('fr', 'stock.confirm_desactiver', 'Désactiver cet article ?'),

    -- Empty states
    ('fr', 'stock.empty_no_mouvement', 'Aucun mouvement'),
    ('fr', 'stock.empty_first_mouvement', 'Enregistrez votre premier mouvement de stock.'),
    ('fr', 'stock.empty_no_article', 'Aucun article'),
    ('fr', 'stock.empty_first_article', 'Créez votre premier article pour commencer.'),
    ('fr', 'stock.empty_no_depot', 'Aucun dépôt'),
    ('fr', 'stock.empty_first_depot', 'Créez votre premier dépôt pour commencer.'),
    ('fr', 'stock.empty_article_not_found', 'Article introuvable'),
    ('fr', 'stock.empty_depot_not_found', 'Dépôt introuvable'),
    ('fr', 'stock.empty_depot_vide', 'Dépôt vide'),
    ('fr', 'stock.empty_no_alerte', 'Aucune alerte'),
    ('fr', 'stock.empty_all_above', 'Tous les articles sont au-dessus du seuil minimum.'),
    ('fr', 'stock.empty_depot_create_first', 'Créez un dépôt avant de faire un inventaire.'),
    ('fr', 'stock.empty_depot_inactive', 'Ce dépôt n''existe pas ou est inactif.'),
    ('fr', 'stock.empty_no_article_actif', 'Aucun article actif dans le catalogue.'),
    ('fr', 'stock.empty_first_mouvement_short', 'Enregistrez votre premier mouvement.'),

    -- Error messages (toast)
    ('fr', 'stock.err_article_not_found', 'Article introuvable'),
    ('fr', 'stock.err_depot_dest_requis', 'Dépôt destination requis pour un transfert'),
    ('fr', 'stock.err_depot_src_dest_identiques', 'Dépôt source et destination identiques'),
    ('fr', 'stock.err_stock_insuffisant', 'Stock insuffisant dans ce dépôt'),
    ('fr', 'stock.err_stock_insuffisant_transfert', 'Stock insuffisant pour le transfert'),
    ('fr', 'stock.err_depot_not_found', 'Dépôt introuvable'),
    ('fr', 'stock.err_depot_inactive', 'Dépôt inexistant ou inactif'),
    ('fr', 'stock.err_no_lignes', 'Aucune ligne à réceptionner'),

    -- Toast messages
    ('fr', 'stock.toast_article_modifie', 'Article modifié'),
    ('fr', 'stock.toast_article_cree', 'Article créé'),
    ('fr', 'stock.toast_article_desactive', 'Article désactivé'),
    ('fr', 'stock.toast_depot_modifie', 'Dépôt modifié'),
    ('fr', 'stock.toast_depot_cree', 'Dépôt créé'),
    ('fr', 'stock.toast_mvt_enregistre', 'Mouvement enregistré'),
    ('fr', 'stock.toast_stock_correct', 'Stock déjà correct, aucun ajustement'),
    ('fr', 'stock.toast_stock_conforme', 'Stock conforme — aucun ajustement'),
    ('fr', 'stock.toast_inventaire_valide', 'Inventaire validé — %s ajustement(s)'),

    -- Info labels (article fiche)
    ('fr', 'stock.label_ref', 'Réf:'),
    ('fr', 'stock.label_categorie', 'Catégorie:'),
    ('fr', 'stock.label_actif', 'Actif:'),
    ('fr', 'stock.label_catalog', 'Catalog:'),
    ('fr', 'stock.label_type', 'Type:'),
    ('fr', 'stock.label_adresse', 'Adresse:'),

    -- Cross-module
    ('fr', 'stock.cross_catalog_voir', 'Voir fiche catalog'),
    ('fr', 'stock.cross_catalog_unavailable', 'catalog non disponible')

  ON CONFLICT DO NOTHING;
END;
$function$;
