CREATE OR REPLACE FUNCTION project.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'project.brand', 'Projets'),
    ('fr', 'project.nav_dashboard', 'Dashboard'),
    ('fr', 'project.nav_projets', 'Projets'),
    ('fr', 'project.nav_planning', 'Planning'),

    -- Statuses (chantier)
    ('fr', 'project.statut_preparation', 'Préparation'),
    ('fr', 'project.statut_execution', 'En cours'),
    ('fr', 'project.statut_reception', 'Réception'),
    ('fr', 'project.statut_clos', 'Clos'),

    -- Statuses (jalon)
    ('fr', 'project.statut_a_faire', 'À faire'),
    ('fr', 'project.statut_en_cours', 'En cours'),
    ('fr', 'project.statut_valide', 'Validé'),

    -- Stats
    ('fr', 'project.stat_en_cours', 'En cours'),
    ('fr', 'project.stat_preparation', 'En préparation'),
    ('fr', 'project.stat_termines_mois', 'Terminés ce mois'),
    ('fr', 'project.stat_heures_semaine', 'Heures semaine'),
    ('fr', 'project.stat_heures_totales', 'Heures totales'),
    ('fr', 'project.stat_client', 'Client'),
    ('fr', 'project.stat_frais', 'Frais'),

    -- Section titles
    ('fr', 'project.title_alertes_retard', 'Alertes retard'),
    ('fr', 'project.title_projets_actifs', 'Projets actifs'),
    ('fr', 'project.title_planning', 'Planning des projets actifs'),
    ('fr', 'project.title_informations', 'Informations'),
    ('fr', 'project.title_avancement', 'Avancement'),

    -- Table headers
    ('fr', 'project.col_numero', 'Numéro'),
    ('fr', 'project.col_client', 'Client'),
    ('fr', 'project.col_objet', 'Objet'),
    ('fr', 'project.col_statut', 'Statut'),
    ('fr', 'project.col_retard', 'Retard'),
    ('fr', 'project.col_avancement', 'Avancement'),
    ('fr', 'project.col_devis', 'Devis'),
    ('fr', 'project.col_debut', 'Début'),
    ('fr', 'project.col_projet', 'Projet'),
    ('fr', 'project.col_periode', 'Période'),
    ('fr', 'project.col_equipe', 'Équipe'),
    ('fr', 'project.col_jalons', 'Jalons'),
    ('fr', 'project.col_order', '#'),
    ('fr', 'project.col_jalon', 'Jalon'),
    ('fr', 'project.col_date_prevue', 'Date prévue'),
    ('fr', 'project.col_actions', 'Actions'),
    ('fr', 'project.col_intervenant', 'Intervenant'),
    ('fr', 'project.col_role', 'Rôle'),
    ('fr', 'project.col_heures_prevues', 'Heures prévues'),
    ('fr', 'project.col_date', 'Date'),
    ('fr', 'project.col_heures', 'Heures'),
    ('fr', 'project.col_description', 'Description'),
    ('fr', 'project.col_contenu', 'Contenu'),
    ('fr', 'project.col_reference', 'Référence'),
    ('fr', 'project.col_auteur', 'Auteur'),
    ('fr', 'project.col_total_ttc', 'Total TTC'),

    -- Tabs
    ('fr', 'project.tab_jalons', 'Jalons'),
    ('fr', 'project.tab_equipe', 'Équipe'),
    ('fr', 'project.tab_pointages', 'Pointages'),
    ('fr', 'project.tab_notes', 'Notes'),
    ('fr', 'project.tab_frais', 'Notes de frais'),

    -- Buttons / Actions
    ('fr', 'project.btn_nouveau', 'Nouveau projet'),
    ('fr', 'project.btn_filtrer', 'Filtrer'),
    ('fr', 'project.btn_modifier', 'Modifier'),
    ('fr', 'project.btn_supprimer', 'Supprimer'),
    ('fr', 'project.btn_ajouter', 'Ajouter'),
    ('fr', 'project.btn_demarrer', 'Démarrer'),
    ('fr', 'project.btn_reception', 'Passer en réception'),
    ('fr', 'project.btn_clore', 'Clore le projet'),
    ('fr', 'project.btn_valider', 'Valider'),
    ('fr', 'project.btn_creer', 'Créer le projet'),
    ('fr', 'project.btn_mettre_a_jour', 'Mettre à jour'),

    -- Field labels
    ('fr', 'project.field_statut', 'Statut'),
    ('fr', 'project.field_client', 'Client'),
    ('fr', 'project.field_choisir', '— Choisir —'),
    ('fr', 'project.field_devis', 'Devis lié (optionnel)'),
    ('fr', 'project.field_aucun', '— Aucun —'),
    ('fr', 'project.field_objet', 'Objet'),
    ('fr', 'project.field_adresse', 'Adresse'),
    ('fr', 'project.field_date_debut', 'Date début'),
    ('fr', 'project.field_date_fin_prevue', 'Date fin prévue'),
    ('fr', 'project.field_fin_reelle', 'Fin réelle'),
    ('fr', 'project.field_notes', 'Notes'),
    ('fr', 'project.field_recherche', 'Recherche'),
    ('fr', 'project.field_date', 'Date'),

    -- Filter values
    ('fr', 'project.filter_tous', 'Tous'),

    -- Placeholders
    ('fr', 'project.ph_recherche', 'Numéro, client, objet…'),
    ('fr', 'project.ph_nouveau_jalon', 'Nouveau jalon...'),
    ('fr', 'project.ph_nom_intervenant', 'Nom intervenant'),
    ('fr', 'project.ph_role', 'Rôle'),
    ('fr', 'project.ph_heures', 'Heures'),
    ('fr', 'project.ph_description', 'Description...'),
    ('fr', 'project.ph_nouvelle_note', 'Nouvelle note...'),

    -- DL (definition list) labels
    ('fr', 'project.dl_objet', 'Objet'),
    ('fr', 'project.dl_adresse', 'Adresse'),
    ('fr', 'project.dl_devis', 'Devis'),
    ('fr', 'project.dl_debut', 'Début'),
    ('fr', 'project.dl_fin_prevue', 'Fin prévue'),
    ('fr', 'project.dl_fin_reelle', 'Fin réelle'),

    -- Empty states
    ('fr', 'project.empty_aucun_actif', 'Aucun projet actif'),
    ('fr', 'project.empty_premier', 'Créez votre premier projet pour commencer.'),
    ('fr', 'project.empty_aucun_trouve', 'Aucun projet trouvé'),
    ('fr', 'project.empty_modifier_filtres', 'Essayez de modifier vos filtres.'),
    ('fr', 'project.empty_introuvable', 'Projet introuvable'),
    ('fr', 'project.empty_aucun_jalon', 'Aucun jalon'),
    ('fr', 'project.empty_aucun_intervenant', 'Aucun intervenant'),
    ('fr', 'project.empty_aucun_pointage', 'Aucun pointage'),
    ('fr', 'project.empty_aucune_note', 'Aucune note'),
    ('fr', 'project.empty_aucun_frais', 'Aucune note de frais liée'),

    -- Breadcrumbs
    ('fr', 'project.bc_projets', 'Projets'),
    ('fr', 'project.bc_modifier', 'Modifier'),
    ('fr', 'project.bc_nouveau', 'Nouveau projet'),

    -- Confirm dialogs
    ('fr', 'project.confirm_demarrer', 'Démarrer ce projet ?'),
    ('fr', 'project.confirm_reception', 'Passer ce projet en réception ?'),
    ('fr', 'project.confirm_clore', 'Clore définitivement ce projet ?'),
    ('fr', 'project.confirm_supprimer', 'Supprimer ce projet ?'),
    ('fr', 'project.confirm_supprimer_jalon', 'Supprimer ce jalon ?'),
    ('fr', 'project.confirm_retirer_intervenant', 'Retirer cet intervenant ?'),
    ('fr', 'project.confirm_supprimer_pointage', 'Supprimer ce pointage ?'),
    ('fr', 'project.confirm_supprimer_note', 'Supprimer cette note ?'),

    -- Toast messages
    ('fr', 'project.toast_enregistre', 'Projet enregistré'),
    ('fr', 'project.toast_demarre', 'Projet démarré'),
    ('fr', 'project.toast_reception', 'Projet passé en réception'),
    ('fr', 'project.toast_clos', 'Projet clos'),
    ('fr', 'project.toast_supprime', 'Projet supprimé'),
    ('fr', 'project.toast_jalon_ajoute', 'Jalon ajouté'),
    ('fr', 'project.toast_avancement_maj', 'Avancement mis à jour'),
    ('fr', 'project.toast_jalon_valide', 'Jalon validé'),
    ('fr', 'project.toast_jalon_supprime', 'Jalon supprimé'),
    ('fr', 'project.toast_note_ajoutee', 'Note ajoutée'),
    ('fr', 'project.toast_note_supprimee', 'Note supprimée'),
    ('fr', 'project.toast_intervenant_ajoute', 'Intervenant ajouté'),
    ('fr', 'project.toast_affectation_supprimee', 'Affectation supprimée'),
    ('fr', 'project.toast_pointage_ajoute', 'Pointage ajouté'),
    ('fr', 'project.toast_pointage_supprime', 'Pointage supprimé'),

    -- Error messages
    ('fr', 'project.err_introuvable', 'Projet introuvable'),
    ('fr', 'project.err_non_modifiable', 'Projet introuvable ou non modifiable'),
    ('fr', 'project.err_pas_preparation', 'Projet introuvable ou pas en préparation'),
    ('fr', 'project.err_pas_reception', 'Projet introuvable ou pas en réception'),
    ('fr', 'project.err_pas_en_cours', 'Projet introuvable ou pas en cours'),
    ('fr', 'project.err_modification_impossible', 'Modification impossible'),
    ('fr', 'project.err_seuls_modifiables', 'Seuls les projets en préparation ou en cours sont modifiables.'),
    ('fr', 'project.err_seuls_supprimables', 'Seuls les projets en préparation peuvent être supprimés.'),
    ('fr', 'project.err_projet_clos_affectation', 'Impossible d''affecter sur un projet clos'),
    ('fr', 'project.err_projet_clos_modification', 'Impossible de modifier un projet clos'),
    ('fr', 'project.err_jalon_non_modifiable', 'Jalon introuvable ou projet non modifiable'),
    ('fr', 'project.err_jalon_deja_valide', 'Jalon introuvable, déjà validé, ou projet non modifiable'),
    ('fr', 'project.err_jalons_precedents', 'Les jalons précédents doivent être validés avant'),
    ('fr', 'project.err_note_non_modifiable', 'Note introuvable ou projet non modifiable'),
    ('fr', 'project.err_pointage_non_modifiable', 'Pointage introuvable ou projet non modifiable'),

    -- Expense statuses (cross-module)
    ('fr', 'project.expense_brouillon', 'Brouillon'),
    ('fr', 'project.expense_soumise', 'Soumise'),
    ('fr', 'project.expense_validee', 'Validée'),
    ('fr', 'project.expense_refusee', 'Refusée')

  ON CONFLICT DO NOTHING;
END;
$function$;
