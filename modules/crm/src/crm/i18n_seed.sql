CREATE OR REPLACE FUNCTION crm.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'crm.brand', 'CRM'),
    ('fr', 'crm.nav_clients', 'Clients'),
    ('fr', 'crm.nav_interactions', 'Interactions'),
    ('fr', 'crm.nav_import', 'Import'),

    -- Types (client + interaction)
    ('fr', 'crm.type_individual', 'Particulier'),
    ('fr', 'crm.type_company', 'Entreprise'),
    ('fr', 'crm.type_call', 'Appel'),
    ('fr', 'crm.type_visit', 'Visite'),
    ('fr', 'crm.type_email', 'Courriel'),
    ('fr', 'crm.type_note', 'Note'),

    -- Field labels
    ('fr', 'crm.field_type', 'Type'),
    ('fr', 'crm.field_name', 'Nom'),
    ('fr', 'crm.field_email', 'Email'),
    ('fr', 'crm.field_phone', 'Téléphone'),
    ('fr', 'crm.field_address', 'Adresse'),
    ('fr', 'crm.field_city', 'Ville'),
    ('fr', 'crm.field_postal_code', 'Code postal'),
    ('fr', 'crm.field_tier', 'Tier'),
    ('fr', 'crm.field_active', 'Actif'),
    ('fr', 'crm.field_notes', 'Notes'),
    ('fr', 'crm.field_role', 'Rôle'),
    ('fr', 'crm.field_tags', 'Tags (séparés par virgules)'),
    ('fr', 'crm.field_subject', 'Sujet'),
    ('fr', 'crm.field_details', 'Détails'),
    ('fr', 'crm.field_period', 'Période'),
    ('fr', 'crm.field_search_name_email', 'Recherche nom/email'),
    ('fr', 'crm.field_search_subject', 'Recherche sujet'),
    ('fr', 'crm.field_csv', 'Contenu CSV'),

    -- Common values
    ('fr', 'crm.yes', 'Oui'),
    ('fr', 'crm.no', 'Non'),
    ('fr', 'crm.filter_all', 'Tous'),
    ('fr', 'crm.filter_all_f', 'Toutes'),

    -- Periods
    ('fr', 'crm.period_week', 'Cette semaine'),
    ('fr', 'crm.period_month', 'Ce mois'),
    ('fr', 'crm.period_3months', '3 derniers mois'),

    -- Stats
    ('fr', 'crm.stat_total_clients', 'Total clients'),
    ('fr', 'crm.stat_new_month', 'Nouveaux ce mois'),
    ('fr', 'crm.stat_interactions_week', 'Interactions cette semaine'),
    ('fr', 'crm.stat_total_interactions', 'Total interactions'),

    -- Table headers
    ('fr', 'crm.col_client', 'Client'),
    ('fr', 'crm.col_type', 'Type'),
    ('fr', 'crm.col_city', 'Ville'),
    ('fr', 'crm.col_tier', 'Tier'),
    ('fr', 'crm.col_interactions', 'Interactions'),
    ('fr', 'crm.col_active', 'Actif'),
    ('fr', 'crm.col_number', 'Numéro'),
    ('fr', 'crm.col_status', 'Statut'),

    -- Buttons / Actions
    ('fr', 'crm.btn_filter', 'Filtrer'),
    ('fr', 'crm.btn_new_client', 'Nouveau client'),
    ('fr', 'crm.btn_import_csv', 'Import CSV'),
    ('fr', 'crm.btn_save', 'Enregistrer'),
    ('fr', 'crm.btn_create_client', 'Créer le client'),
    ('fr', 'crm.btn_add', 'Ajouter'),
    ('fr', 'crm.btn_delete', 'Supprimer'),
    ('fr', 'crm.btn_edit', 'Modifier'),
    ('fr', 'crm.btn_import', 'Importer'),

    -- Section titles
    ('fr', 'crm.title_contacts', 'Contacts'),
    ('fr', 'crm.title_add_contact', 'Ajouter un contact'),
    ('fr', 'crm.title_add_interaction', 'Ajouter une interaction'),
    ('fr', 'crm.title_activity', 'Activité liée'),
    ('fr', 'crm.title_new_client', 'Nouveau client'),
    ('fr', 'crm.title_fiche', 'Fiche'),
    ('fr', 'crm.title_timeline', 'Timeline'),

    -- Cross-module labels
    ('fr', 'crm.cross_quotes', 'Devis'),
    ('fr', 'crm.cross_invoices', 'Factures'),
    ('fr', 'crm.cross_revenue', 'CA TTC'),
    ('fr', 'crm.cross_projects', 'Projets'),
    ('fr', 'crm.cross_purchase_orders', 'Commandes fournisseur'),
    ('fr', 'crm.cross_see', 'Voir'),

    -- Contact badge
    ('fr', 'crm.badge_primary', 'Principal'),
    ('fr', 'crm.label_primary_contact', 'Contact principal'),

    -- Empty states
    ('fr', 'crm.empty_no_contacts', 'Aucun contact'),
    ('fr', 'crm.empty_no_events', 'Aucun événement'),
    ('fr', 'crm.empty_no_client', 'Aucun client'),
    ('fr', 'crm.empty_first_client', 'Créez votre premier client pour commencer.'),
    ('fr', 'crm.empty_no_results', 'Aucun résultat pour ces filtres.'),
    ('fr', 'crm.empty_no_interaction', 'Aucune interaction.'),

    -- Error messages
    ('fr', 'crm.err_not_found', 'Client introuvable.'),
    ('fr', 'crm.err_name_required', 'Le nom est obligatoire.'),
    ('fr', 'crm.err_subject_required', 'Le sujet est obligatoire.'),
    ('fr', 'crm.err_no_csv', 'Aucun contenu CSV fourni.'),
    ('fr', 'crm.err_no_import', 'Aucun client importé.'),

    -- Toast messages
    ('fr', 'crm.toast_client_saved', 'Client modifié.'),
    ('fr', 'crm.toast_client_created', 'Client créé.'),
    ('fr', 'crm.toast_client_deleted', 'Client supprimé.'),
    ('fr', 'crm.toast_contact_added', 'Contact ajouté.'),
    ('fr', 'crm.toast_contact_deleted', 'Contact supprimé.'),
    ('fr', 'crm.toast_interaction_added', 'Interaction ajoutée.'),

    -- Confirm dialogs
    ('fr', 'crm.confirm_delete_contact', 'Supprimer ce contact ?'),
    ('fr', 'crm.confirm_delete_client', 'Supprimer définitivement ce client et tout son historique ?'),

    -- Import page
    ('fr', 'crm.import_intro', 'Collez votre CSV ci-dessous. Colonnes attendues :'),
    ('fr', 'crm.import_help', 'Séparateur : ; ou , — la ligne d''en-tête est ignorée si elle contient "nom". Le type accepte individual ou company (défaut: individual).')

  ON CONFLICT DO NOTHING;
END;
$function$;
