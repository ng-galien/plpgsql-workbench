CREATE OR REPLACE FUNCTION hr.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'hr.brand', 'RH'),
    ('fr', 'hr.nav_salaries', 'Salariés'),
    ('fr', 'hr.nav_absences', 'Absences'),
    ('fr', 'hr.nav_heures', 'Heures'),
    ('fr', 'hr.nav_registre', 'Registre'),

    -- Contract types
    ('fr', 'hr.contrat_cdi', 'CDI'),
    ('fr', 'hr.contrat_cdd', 'CDD'),
    ('fr', 'hr.contrat_alternance', 'Alternance'),
    ('fr', 'hr.contrat_stage', 'Stage'),
    ('fr', 'hr.contrat_interim', 'Intérim'),

    -- Absence types
    ('fr', 'hr.absence_conge_paye', 'Congé payé'),
    ('fr', 'hr.absence_rtt', 'RTT'),
    ('fr', 'hr.absence_maladie', 'Maladie'),
    ('fr', 'hr.absence_sans_solde', 'Sans solde'),
    ('fr', 'hr.absence_formation', 'Formation'),
    ('fr', 'hr.absence_autre', 'Autre'),

    -- Sexe
    ('fr', 'hr.sexe_m', 'Homme'),
    ('fr', 'hr.sexe_f', 'Femme'),

    -- Status
    ('fr', 'hr.statut_actif', 'Actif'),
    ('fr', 'hr.statut_inactif', 'Inactif'),
    ('fr', 'hr.statut_demande', 'Demande'),
    ('fr', 'hr.statut_validee', 'Validée'),
    ('fr', 'hr.statut_refusee', 'Refusée'),
    ('fr', 'hr.statut_annulee', 'Annulée'),

    -- Field labels
    ('fr', 'hr.field_nom', 'Nom'),
    ('fr', 'hr.field_prenom', 'Prénom'),
    ('fr', 'hr.field_email', 'Email'),
    ('fr', 'hr.field_phone', 'Téléphone'),
    ('fr', 'hr.field_matricule', 'Matricule'),
    ('fr', 'hr.field_date_naissance', 'Date de naissance'),
    ('fr', 'hr.field_sexe', 'Sexe'),
    ('fr', 'hr.field_nationalite', 'Nationalité'),
    ('fr', 'hr.field_poste', 'Poste'),
    ('fr', 'hr.field_departement', 'Département'),
    ('fr', 'hr.field_qualification', 'Qualification'),
    ('fr', 'hr.field_type_contrat', 'Type de contrat'),
    ('fr', 'hr.field_date_embauche', 'Date d''embauche'),
    ('fr', 'hr.field_date_fin', 'Date de fin'),
    ('fr', 'hr.field_heures_hebdo', 'Heures/semaine'),
    ('fr', 'hr.field_notes', 'Notes'),
    ('fr', 'hr.field_motif', 'Motif'),
    ('fr', 'hr.field_nb_jours', 'Nombre de jours'),
    ('fr', 'hr.field_date_debut', 'Date début'),
    ('fr', 'hr.field_date_fin_absence', 'Date fin'),
    ('fr', 'hr.field_description', 'Description'),
    ('fr', 'hr.field_heures', 'Heures'),
    ('fr', 'hr.field_date_travail', 'Date'),
    ('fr', 'hr.field_allocated', 'Alloués'),
    ('fr', 'hr.field_used', 'Pris'),
    ('fr', 'hr.field_remaining', 'Restants'),

    -- Stats
    ('fr', 'hr.stat_total', 'Total salariés'),
    ('fr', 'hr.stat_actifs', 'Actifs'),
    ('fr', 'hr.stat_en_absence', 'En absence'),
    ('fr', 'hr.stat_en_cours', 'En cours'),
    ('fr', 'hr.stat_en_attente', 'En attente'),
    ('fr', 'hr.stat_ce_mois', 'Ce mois'),
    ('fr', 'hr.stat_semaine_du', 'Semaine du'),
    ('fr', 'hr.stat_total_heures', 'Total heures'),
    ('fr', 'hr.stat_salaries', 'Salariés'),
    ('fr', 'hr.stat_heures_30j', 'Heures (30j)'),

    -- Table headers
    ('fr', 'hr.col_salarie', 'Salarié'),
    ('fr', 'hr.col_poste', 'Poste'),
    ('fr', 'hr.col_departement', 'Département'),
    ('fr', 'hr.col_contrat', 'Contrat'),
    ('fr', 'hr.col_embauche', 'Embauche'),
    ('fr', 'hr.col_statut', 'Statut'),
    ('fr', 'hr.col_type', 'Type'),
    ('fr', 'hr.col_debut', 'Début'),
    ('fr', 'hr.col_fin', 'Fin'),
    ('fr', 'hr.col_jours', 'Jours'),
    ('fr', 'hr.col_actions', 'Actions'),
    ('fr', 'hr.col_date', 'Date'),
    ('fr', 'hr.col_heures', 'Heures'),
    ('fr', 'hr.col_objectif', 'Objectif'),
    ('fr', 'hr.col_sexe', 'Sexe'),
    ('fr', 'hr.col_nationalite', 'Nationalité'),
    ('fr', 'hr.col_naissance', 'Naissance'),
    ('fr', 'hr.col_emploi', 'Emploi'),
    ('fr', 'hr.col_qualification', 'Qualification'),
    ('fr', 'hr.col_entree', 'Entrée'),
    ('fr', 'hr.col_sortie', 'Sortie'),
    ('fr', 'hr.col_matricule', 'Matricule'),
    ('fr', 'hr.col_nom_prenom', 'Nom Prénom'),

    -- Buttons / Actions
    ('fr', 'hr.btn_filtrer', 'Filtrer'),
    ('fr', 'hr.btn_nouveau_salarie', 'Nouveau salarié'),
    ('fr', 'hr.btn_enregistrer', 'Enregistrer'),
    ('fr', 'hr.btn_annuler', 'Annuler'),
    ('fr', 'hr.btn_modifier', 'Modifier'),
    ('fr', 'hr.btn_supprimer', 'Supprimer'),
    ('fr', 'hr.btn_valider', 'Valider'),
    ('fr', 'hr.btn_refuser', 'Refuser'),
    ('fr', 'hr.btn_declarer', 'Déclarer'),

    -- Section titles
    ('fr', 'hr.title_fiche', 'Fiche'),
    ('fr', 'hr.title_absences', 'Absences'),
    ('fr', 'hr.title_heures', 'Heures'),
    ('fr', 'hr.title_declarer_absence', 'Déclarer une absence'),
    ('fr', 'hr.title_saisir_heures', 'Saisir des heures'),
    ('fr', 'hr.title_registre', 'Registre du personnel'),
    ('fr', 'hr.title_registre_notice', 'Registre obligatoire (Art. L1221-13 du Code du travail)'),

    -- Empty states
    ('fr', 'hr.empty_no_salarie', 'Aucun salarié'),
    ('fr', 'hr.empty_first_salarie', 'Ajoutez votre premier salarié pour commencer.'),
    ('fr', 'hr.empty_no_results', 'Aucun résultat pour ces filtres.'),
    ('fr', 'hr.empty_no_absence', 'Aucune absence enregistrée'),
    ('fr', 'hr.empty_no_absence_found', 'Aucune absence trouvée.'),
    ('fr', 'hr.empty_no_heures', 'Aucune heure saisie'),
    ('fr', 'hr.empty_no_actif', 'Aucun salarié actif.'),

    -- Toast messages
    ('fr', 'hr.toast_employee_created', 'Salarié créé.'),
    ('fr', 'hr.toast_employee_updated', 'Salarié mis à jour.'),
    ('fr', 'hr.toast_employee_deleted', 'Salarié supprimé.'),
    ('fr', 'hr.toast_absence_declared', 'Absence déclarée.'),
    ('fr', 'hr.toast_timesheet_saved', 'Heures enregistrées.'),
    ('fr', 'hr.toast_balance_insufficient', 'Solde insuffisant.'),

    -- Error messages
    ('fr', 'hr.err_not_found', 'Salarié introuvable.'),
    ('fr', 'hr.err_nom_prenom_required', 'Nom et prénom obligatoires.'),
    ('fr', 'hr.err_dates_required', 'Dates et nombre de jours obligatoires.'),
    ('fr', 'hr.err_date_order', 'La date de fin doit être après la date de début.'),
    ('fr', 'hr.err_heures_range', 'Heures entre 0 et 24.'),
    ('fr', 'hr.err_already_processed', 'Absence introuvable ou déjà traitée.'),

    -- Confirm dialogs
    ('fr', 'hr.confirm_delete_employee', 'Supprimer définitivement ce salarié et tout son historique ?'),

    -- Badge labels
    ('fr', 'hr.badge_ok', 'OK'),
    ('fr', 'hr.badge_partiel', 'Partiel'),
    ('fr', 'hr.badge_vide', 'Vide'),

    -- Entity labels (_view)
    ('fr', 'hr.entity_employee', 'Salarié'),
    ('fr', 'hr.entity_absence', 'Absence'),
    ('fr', 'hr.entity_timesheet', 'Pointage'),

    -- Section labels (_view form)
    ('fr', 'hr.section_identity', 'Identité'),
    ('fr', 'hr.section_position', 'Poste'),
    ('fr', 'hr.section_contract', 'Contrat'),
    ('fr', 'hr.section_absence', 'Absence'),
    ('fr', 'hr.section_timesheet', 'Pointage'),

    -- Action labels (_view HATEOAS)
    ('fr', 'hr.action_deactivate', 'Désactiver'),
    ('fr', 'hr.action_activate', 'Réactiver'),
    ('fr', 'hr.action_delete', 'Supprimer'),
    ('fr', 'hr.action_validate', 'Valider'),
    ('fr', 'hr.action_refuse', 'Refuser'),
    ('fr', 'hr.action_cancel', 'Annuler'),

    -- Stat labels (_view)
    ('fr', 'hr.stat_cp_remaining', 'CP restants'),
    ('fr', 'hr.stat_rtt_remaining', 'RTT restants'),
    ('fr', 'hr.stat_absences', 'Absences'),
    ('fr', 'hr.stat_balance_remaining', 'Solde restant'),

    -- Related labels (_view)
    ('fr', 'hr.rel_absences', 'Absences'),
    ('fr', 'hr.rel_timesheets', 'Pointages'),
    ('fr', 'hr.rel_employee', 'Salarié'),

    -- Form field labels (_view)
    ('fr', 'hr.field_employee', 'Salarié'),
    ('fr', 'hr.field_type_absence', 'Type d''absence'),

    -- Confirm dialogs (_view)
    ('fr', 'hr.confirm_delete_absence', 'Supprimer cette absence ?'),
    ('fr', 'hr.confirm_delete_timesheet', 'Supprimer ce pointage ?')

  ON CONFLICT DO NOTHING;
END;
$function$;
