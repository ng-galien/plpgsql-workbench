CREATE OR REPLACE FUNCTION planning.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'planning.brand', 'Planning'),
    ('fr', 'planning.nav_agenda', 'Agenda'),
    ('fr', 'planning.nav_equipe', 'Équipe'),
    ('fr', 'planning.nav_evenements', 'Événements'),

    -- Event types
    ('fr', 'planning.type_chantier', 'Chantier'),
    ('fr', 'planning.type_livraison', 'Livraison'),
    ('fr', 'planning.type_reunion', 'Réunion'),
    ('fr', 'planning.type_conge', 'Congé'),
    ('fr', 'planning.type_autre', 'Autre'),

    -- Status
    ('fr', 'planning.statut_actif', 'Actif'),
    ('fr', 'planning.statut_inactif', 'Inactif'),

    -- Field labels
    ('fr', 'planning.field_nom', 'Nom'),
    ('fr', 'planning.field_role', 'Rôle'),
    ('fr', 'planning.field_telephone', 'Téléphone'),
    ('fr', 'planning.field_couleur', 'Couleur agenda'),
    ('fr', 'planning.field_actif', 'Actif'),
    ('fr', 'planning.field_titre', 'Titre'),
    ('fr', 'planning.field_type', 'Type'),
    ('fr', 'planning.field_date_debut', 'Date début'),
    ('fr', 'planning.field_date_fin', 'Date fin'),
    ('fr', 'planning.field_heure_debut', 'Heure début'),
    ('fr', 'planning.field_heure_fin', 'Heure fin'),
    ('fr', 'planning.field_lieu', 'Lieu'),
    ('fr', 'planning.field_chantier', 'Chantier (optionnel)'),
    ('fr', 'planning.field_notes', 'Notes'),
    ('fr', 'planning.field_role_hint', 'ex: charpentier, électricien'),
    ('fr', 'planning.field_ajoute_le', 'Ajouté le'),

    -- Stats
    ('fr', 'planning.stat_intervenants', 'Intervenants actifs'),
    ('fr', 'planning.stat_evenements_semaine', 'Événements semaine'),
    ('fr', 'planning.stat_affectations_semaine', 'Affectations semaine'),

    -- Table headers
    ('fr', 'planning.col_intervenant', 'Intervenant'),
    ('fr', 'planning.col_nom', 'Nom'),
    ('fr', 'planning.col_role', 'Rôle'),
    ('fr', 'planning.col_telephone', 'Téléphone'),
    ('fr', 'planning.col_couleur', 'Couleur'),
    ('fr', 'planning.col_evt_actifs', 'Évén. actifs'),
    ('fr', 'planning.col_statut', 'Statut'),
    ('fr', 'planning.col_evenement', 'Événement'),
    ('fr', 'planning.col_type', 'Type'),
    ('fr', 'planning.col_dates', 'Dates'),
    ('fr', 'planning.col_lieu', 'Lieu'),
    ('fr', 'planning.col_intervenants', 'Intervenants'),
    ('fr', 'planning.col_chantier', 'Chantier'),

    -- Buttons / Actions
    ('fr', 'planning.btn_filtrer', 'Filtrer'),
    ('fr', 'planning.btn_enregistrer', 'Enregistrer'),
    ('fr', 'planning.btn_modifier', 'Modifier'),
    ('fr', 'planning.btn_supprimer', 'Supprimer'),
    ('fr', 'planning.btn_affecter', 'Affecter'),
    ('fr', 'planning.btn_retirer', 'Retirer'),
    ('fr', 'planning.btn_nouvel_evenement', 'Nouvel événement'),
    ('fr', 'planning.btn_nouvel_intervenant', 'Nouvel intervenant'),
    ('fr', 'planning.btn_gerer_equipe', 'Gérer l''équipe'),
    ('fr', 'planning.btn_ajouter_intervenant', 'Ajouter un intervenant'),

    -- Section titles
    ('fr', 'planning.title_equipe_affectee', 'Équipe affectée'),
    ('fr', 'planning.title_evenements_venir', 'Événements à venir'),
    ('fr', 'planning.title_semaine_du', 'Semaine du'),

    -- Filter labels
    ('fr', 'planning.filter_recherche_nom', 'Recherche nom/rôle'),
    ('fr', 'planning.filter_recherche_titre', 'Recherche titre/lieu'),
    ('fr', 'planning.filter_statut', 'Statut'),
    ('fr', 'planning.filter_tous', 'Tous'),
    ('fr', 'planning.filter_actifs', 'Actifs'),
    ('fr', 'planning.filter_inactifs', 'Inactifs'),
    ('fr', 'planning.filter_a_partir_du', 'À partir du'),

    -- Empty states
    ('fr', 'planning.empty_no_intervenant', 'Aucun intervenant'),
    ('fr', 'planning.empty_first_intervenant', 'Ajoutez des membres à votre équipe pour commencer.'),
    ('fr', 'planning.empty_equipe', 'Ajoutez des membres à votre équipe.'),
    ('fr', 'planning.empty_no_evenement', 'Aucun événement'),
    ('fr', 'planning.empty_no_affectation', 'Aucun intervenant affecté'),
    ('fr', 'planning.empty_no_evt_venir', 'Aucun événement à venir'),

    -- Toast messages
    ('fr', 'planning.toast_intervenant_saved', 'Intervenant enregistré'),
    ('fr', 'planning.toast_intervenant_deleted', 'Intervenant supprimé'),
    ('fr', 'planning.toast_evenement_saved', 'Événement enregistré'),
    ('fr', 'planning.toast_evenement_deleted', 'Événement supprimé'),
    ('fr', 'planning.toast_affecte', 'Intervenant affecté'),
    ('fr', 'planning.toast_desaffecte', 'Intervenant retiré'),
    ('fr', 'planning.toast_affectation_not_found', 'Affectation introuvable'),

    -- Error messages
    ('fr', 'planning.err_nom_required', 'Le nom est obligatoire'),
    ('fr', 'planning.err_titre_required', 'Le titre est obligatoire'),
    ('fr', 'planning.err_date_order', 'La date de fin doit être >= date de début'),
    ('fr', 'planning.err_intervenant_not_found', 'Intervenant introuvable'),
    ('fr', 'planning.err_evenement_not_found', 'Événement introuvable'),

    -- Confirm dialogs
    ('fr', 'planning.confirm_delete_intervenant', 'Supprimer cet intervenant ?'),
    ('fr', 'planning.confirm_delete_evenement', 'Supprimer cet événement ?')

  ON CONFLICT DO NOTHING;
END;
$function$;
