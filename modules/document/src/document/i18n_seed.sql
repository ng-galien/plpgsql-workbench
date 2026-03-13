CREATE OR REPLACE FUNCTION document.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'document.brand', 'Documents'),
    ('fr', 'document.nav_templates', 'Templates'),
    ('fr', 'document.nav_documents', 'Documents'),
    ('fr', 'document.nav_company', 'Émetteur'),

    -- Stats
    ('fr', 'document.stat_templates', 'Templates'),
    ('fr', 'document.stat_documents', 'Documents'),
    ('fr', 'document.stat_draft', 'Brouillons'),
    ('fr', 'document.stat_generated', 'Générés'),

    -- Column headers
    ('fr', 'document.col_name', 'Nom'),
    ('fr', 'document.col_doc_type', 'Type'),
    ('fr', 'document.col_format', 'Format'),
    ('fr', 'document.col_default', 'Défaut'),
    ('fr', 'document.col_version', 'Version'),
    ('fr', 'document.col_created', 'Créé le'),
    ('fr', 'document.col_title', 'Titre'),
    ('fr', 'document.col_ref', 'Référence'),
    ('fr', 'document.col_status', 'Statut'),
    ('fr', 'document.col_module', 'Module'),

    -- Field labels
    ('fr', 'document.field_name', 'Raison sociale'),
    ('fr', 'document.field_siret', 'SIRET'),
    ('fr', 'document.field_tva_intra', 'TVA intracommunautaire'),
    ('fr', 'document.field_address', 'Adresse'),
    ('fr', 'document.field_city', 'Ville'),
    ('fr', 'document.field_postal_code', 'Code postal'),
    ('fr', 'document.field_phone', 'Téléphone'),
    ('fr', 'document.field_email', 'Email'),
    ('fr', 'document.field_website', 'Site web'),
    ('fr', 'document.field_mentions', 'Mentions légales'),
    ('fr', 'document.field_doc_type', 'Type de document'),
    ('fr', 'document.field_status', 'Statut'),
    ('fr', 'document.field_search', 'Recherche'),

    -- Filter values
    ('fr', 'document.filter_all', 'Tous'),

    -- Status labels
    ('fr', 'document.status_draft', 'Brouillon'),
    ('fr', 'document.status_generated', 'Généré'),
    ('fr', 'document.status_signed', 'Signé'),
    ('fr', 'document.status_archived', 'Archivé'),

    -- Buttons
    ('fr', 'document.btn_save', 'Enregistrer'),

    -- Titles
    ('fr', 'document.title_company', 'Informations émetteur'),
    ('fr', 'document.title_company_empty', 'Aucune information émetteur configurée'),
    ('fr', 'document.title_company_help', 'Renseignez les informations de votre entreprise pour les documents.'),

    -- Empty states
    ('fr', 'document.empty_no_template', 'Aucun template'),
    ('fr', 'document.empty_first_template', 'Les templates seront créés via l''illustrateur.'),
    ('fr', 'document.empty_no_document', 'Aucun document'),
    ('fr', 'document.empty_first_document', 'Les documents seront générés depuis les modules ERP.'),

    -- Toast
    ('fr', 'document.toast_company_saved', 'Informations émetteur enregistrées.'),

    -- Doc types
    ('fr', 'document.type_facture', 'Facture'),
    ('fr', 'document.type_devis', 'Devis'),
    ('fr', 'document.type_bon_commande', 'Bon de commande'),
    ('fr', 'document.type_bon_livraison', 'Bon de livraison'),
    ('fr', 'document.type_avoir', 'Avoir'),
    ('fr', 'document.type_registre', 'Registre'),

    -- Yes/No
    ('fr', 'document.yes', 'Oui'),
    ('fr', 'document.no', 'Non')

  ON CONFLICT DO NOTHING;
END;
$function$;
