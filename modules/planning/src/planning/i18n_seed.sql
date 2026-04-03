CREATE OR REPLACE FUNCTION planning.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Delete stale French keys from pre-rename era
  DELETE FROM pgv.i18n WHERE lang = 'fr' AND key IN (
    'planning.btn_affecter', 'planning.btn_ajouter_intervenant', 'planning.btn_enregistrer',
    'planning.btn_filtrer', 'planning.btn_gerer_equipe', 'planning.btn_modifier',
    'planning.btn_nouvel_evenement', 'planning.btn_nouvel_intervenant', 'planning.btn_retirer',
    'planning.btn_supprimer',
    'planning.col_chantier', 'planning.col_couleur', 'planning.col_evenement',
    'planning.col_evt_actifs', 'planning.col_intervenant', 'planning.col_intervenants',
    'planning.col_lieu', 'planning.col_nom', 'planning.col_statut', 'planning.col_telephone',
    'planning.confirm_delete_evenement', 'planning.confirm_delete_intervenant',
    'planning.empty_equipe', 'planning.empty_first_intervenant', 'planning.empty_no_affectation',
    'planning.empty_no_evenement', 'planning.empty_no_evt_venir', 'planning.empty_no_intervenant',
    'planning.err_evenement_not_found', 'planning.err_intervenant_not_found',
    'planning.err_nom_required', 'planning.err_titre_required',
    'planning.field_actif', 'planning.field_ajoute_le', 'planning.field_chantier',
    'planning.field_couleur', 'planning.field_date_debut', 'planning.field_date_fin',
    'planning.field_heure_debut', 'planning.field_heure_fin', 'planning.field_lieu',
    'planning.field_nom', 'planning.field_telephone', 'planning.field_titre',
    'planning.filter_a_partir_du', 'planning.filter_actifs', 'planning.filter_inactifs',
    'planning.filter_recherche_nom', 'planning.filter_recherche_titre',
    'planning.filter_statut', 'planning.filter_tous',
    'planning.nav_equipe', 'planning.nav_evenements',
    'planning.stat_affectations_semaine', 'planning.stat_evenements_semaine',
    'planning.stat_intervenants',
    'planning.statut_actif', 'planning.statut_inactif',
    'planning.title_equipe_affectee', 'planning.title_evenements_venir', 'planning.title_semaine_du',
    'planning.toast_affectation_not_found', 'planning.toast_affecte', 'planning.toast_desaffecte',
    'planning.toast_evenement_deleted', 'planning.toast_evenement_saved',
    'planning.toast_intervenant_deleted', 'planning.toast_intervenant_saved',
    'planning.type_autre', 'planning.type_chantier', 'planning.type_conge',
    'planning.type_livraison', 'planning.type_reunion'
  );

  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'planning.brand', 'Planning'),
    ('fr', 'planning.nav_agenda', 'Agenda'),
    ('fr', 'planning.nav_team', 'Équipe'),
    ('fr', 'planning.nav_events', 'Événements'),
    -- Event types
    ('fr', 'planning.type_job_site', 'Chantier'),
    ('fr', 'planning.type_delivery', 'Livraison'),
    ('fr', 'planning.type_meeting', 'Réunion'),
    ('fr', 'planning.type_leave', 'Congé'),
    ('fr', 'planning.type_other', 'Autre'),
    -- Status
    ('fr', 'planning.status_active', 'Actif'),
    ('fr', 'planning.status_inactive', 'Inactif'),
    -- Field labels
    ('fr', 'planning.field_name', 'Nom'),
    ('fr', 'planning.field_role', 'Rôle'),
    ('fr', 'planning.field_phone', 'Téléphone'),
    ('fr', 'planning.field_color', 'Couleur agenda'),
    ('fr', 'planning.field_active', 'Actif'),
    ('fr', 'planning.field_title', 'Titre'),
    ('fr', 'planning.field_type', 'Type'),
    ('fr', 'planning.field_start_date', 'Date début'),
    ('fr', 'planning.field_end_date', 'Date fin'),
    ('fr', 'planning.field_start_time', 'Heure début'),
    ('fr', 'planning.field_end_time', 'Heure fin'),
    ('fr', 'planning.field_location', 'Lieu'),
    ('fr', 'planning.field_project', 'Projet (optionnel)'),
    ('fr', 'planning.field_notes', 'Notes'),
    ('fr', 'planning.field_role_hint', 'ex: charpentier, électricien'),
    ('fr', 'planning.field_created_at', 'Ajouté le'),
    -- Stats
    ('fr', 'planning.stat_workers', 'Intervenants actifs'),
    ('fr', 'planning.stat_events_week', 'Événements semaine'),
    ('fr', 'planning.stat_assignments_week', 'Affectations semaine'),
    ('fr', 'planning.stat_active_events', 'Événements actifs'),
    -- Table headers
    ('fr', 'planning.col_worker', 'Intervenant'),
    ('fr', 'planning.col_name', 'Nom'),
    ('fr', 'planning.col_role', 'Rôle'),
    ('fr', 'planning.col_phone', 'Téléphone'),
    ('fr', 'planning.col_color', 'Couleur'),
    ('fr', 'planning.col_active_events', 'Évén. actifs'),
    ('fr', 'planning.col_status', 'Statut'),
    ('fr', 'planning.col_event', 'Événement'),
    ('fr', 'planning.col_type', 'Type'),
    ('fr', 'planning.col_dates', 'Dates'),
    ('fr', 'planning.col_location', 'Lieu'),
    ('fr', 'planning.col_workers', 'Intervenants'),
    ('fr', 'planning.col_project', 'Projet'),
    -- Buttons / Actions
    ('fr', 'planning.btn_filter', 'Filtrer'),
    ('fr', 'planning.btn_save', 'Enregistrer'),
    ('fr', 'planning.btn_edit', 'Modifier'),
    ('fr', 'planning.btn_delete', 'Supprimer'),
    ('fr', 'planning.btn_assign', 'Affecter'),
    ('fr', 'planning.btn_remove', 'Retirer'),
    ('fr', 'planning.btn_new_event', 'Nouvel événement'),
    ('fr', 'planning.btn_new_worker', 'Nouvel intervenant'),
    ('fr', 'planning.btn_manage_team', 'Gérer l''équipe'),
    ('fr', 'planning.btn_add_worker', 'Ajouter un intervenant'),
    -- Section titles
    ('fr', 'planning.title_assigned_team', 'Équipe affectée'),
    ('fr', 'planning.title_upcoming_events', 'Événements à venir'),
    ('fr', 'planning.title_week_of', 'Semaine du'),
    -- Filter labels
    ('fr', 'planning.filter_search_name', 'Recherche nom/rôle'),
    ('fr', 'planning.filter_search_title', 'Recherche titre/lieu'),
    ('fr', 'planning.filter_status', 'Statut'),
    ('fr', 'planning.filter_all', 'Tous'),
    ('fr', 'planning.filter_active', 'Actifs'),
    ('fr', 'planning.filter_inactive', 'Inactifs'),
    ('fr', 'planning.filter_from_date', 'À partir du'),
    -- Empty states
    ('fr', 'planning.empty_no_worker', 'Aucun intervenant'),
    ('fr', 'planning.empty_first_worker', 'Ajoutez des membres à votre équipe pour commencer.'),
    ('fr', 'planning.empty_add_team', 'Ajoutez des membres à votre équipe.'),
    ('fr', 'planning.empty_no_event', 'Aucun événement'),
    ('fr', 'planning.empty_no_assignment', 'Aucun intervenant affecté'),
    ('fr', 'planning.empty_no_upcoming_event', 'Aucun événement à venir'),
    -- Toast messages
    ('fr', 'planning.toast_worker_saved', 'Intervenant enregistré'),
    ('fr', 'planning.toast_worker_deleted', 'Intervenant supprimé'),
    ('fr', 'planning.toast_event_saved', 'Événement enregistré'),
    ('fr', 'planning.toast_event_deleted', 'Événement supprimé'),
    ('fr', 'planning.toast_assigned', 'Intervenant affecté'),
    ('fr', 'planning.toast_unassigned', 'Intervenant retiré'),
    ('fr', 'planning.toast_assignment_not_found', 'Affectation introuvable'),
    -- Error messages
    ('fr', 'planning.err_name_required', 'Le nom est obligatoire'),
    ('fr', 'planning.err_title_required', 'Le titre est obligatoire'),
    ('fr', 'planning.err_date_order', 'La date de fin doit être >= date de début'),
    ('fr', 'planning.err_worker_not_found', 'Intervenant introuvable'),
    ('fr', 'planning.err_event_not_found', 'Événement introuvable'),
    -- Confirm dialogs
    ('fr', 'planning.confirm_delete_worker', 'Supprimer cet intervenant ?'),
    ('fr', 'planning.confirm_delete_event', 'Supprimer cet événement ?'),
    ('fr', 'planning.confirm_deactivate', 'Désactiver cet intervenant ?'),
    -- Entity labels
    ('fr', 'planning.entity_worker', 'Intervenant'),
    ('fr', 'planning.entity_event', 'Événement'),
    -- Actions (_view)
    ('fr', 'planning.action_deactivate', 'Désactiver'),
    ('fr', 'planning.action_activate', 'Activer'),
    ('fr', 'planning.action_delete', 'Supprimer'),
    -- Sections (_view form)
    ('fr', 'planning.section_identity', 'Identité'),
    ('fr', 'planning.section_general', 'Général'),
    ('fr', 'planning.section_schedule', 'Planification'),
    ('fr', 'planning.section_location', 'Localisation'),
    -- Related
    ('fr', 'planning.rel_project', 'Projet lié')
  ON CONFLICT DO NOTHING;
END;
$function$;
