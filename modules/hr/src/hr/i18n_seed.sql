CREATE OR REPLACE FUNCTION hr.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    -- Brand / Navigation
    ('fr', 'hr.brand', 'RH'),
    ('fr', 'hr.nav_employees', 'Salariés'),
    ('fr', 'hr.nav_absences', 'Absences'),
    ('fr', 'hr.nav_timesheets', 'Heures'),
    ('fr', 'hr.nav_register', 'Registre'),

    -- Contract types
    ('fr', 'hr.contract_cdi', 'CDI'),
    ('fr', 'hr.contract_cdd', 'CDD'),
    ('fr', 'hr.contract_apprenticeship', 'Alternance'),
    ('fr', 'hr.contract_internship', 'Stage'),
    ('fr', 'hr.contract_temp', 'Intérim'),

    -- Absence types
    ('fr', 'hr.absence_paid_leave', 'Congé payé'),
    ('fr', 'hr.absence_rtt', 'RTT'),
    ('fr', 'hr.absence_sick', 'Maladie'),
    ('fr', 'hr.absence_unpaid', 'Sans solde'),
    ('fr', 'hr.absence_training', 'Formation'),
    ('fr', 'hr.absence_other', 'Autre'),

    -- Gender
    ('fr', 'hr.gender_m', 'Homme'),
    ('fr', 'hr.gender_f', 'Femme'),

    -- Status
    ('fr', 'hr.status_active', 'Actif'),
    ('fr', 'hr.status_inactive', 'Inactif'),
    ('fr', 'hr.status_pending', 'Demande'),
    ('fr', 'hr.status_approved', 'Validée'),
    ('fr', 'hr.status_rejected', 'Refusée'),
    ('fr', 'hr.status_cancelled', 'Annulée'),

    -- Field labels
    ('fr', 'hr.field_last_name', 'Nom'),
    ('fr', 'hr.field_first_name', 'Prénom'),
    ('fr', 'hr.field_email', 'Email'),
    ('fr', 'hr.field_phone', 'Téléphone'),
    ('fr', 'hr.field_employee_code', 'Matricule'),
    ('fr', 'hr.field_birth_date', 'Date de naissance'),
    ('fr', 'hr.field_gender', 'Sexe'),
    ('fr', 'hr.field_nationality', 'Nationalité'),
    ('fr', 'hr.field_position', 'Poste'),
    ('fr', 'hr.field_department', 'Département'),
    ('fr', 'hr.field_qualification', 'Qualification'),
    ('fr', 'hr.field_contract_type', 'Type de contrat'),
    ('fr', 'hr.field_hire_date', 'Date d''embauche'),
    ('fr', 'hr.field_end_date', 'Date de fin'),
    ('fr', 'hr.field_weekly_hours', 'Heures/semaine'),
    ('fr', 'hr.field_notes', 'Notes'),
    ('fr', 'hr.field_reason', 'Motif'),
    ('fr', 'hr.field_day_count', 'Nombre de jours'),
    ('fr', 'hr.field_start_date', 'Date début'),
    ('fr', 'hr.field_end_date_absence', 'Date fin'),
    ('fr', 'hr.field_description', 'Description'),
    ('fr', 'hr.field_hours', 'Heures'),
    ('fr', 'hr.field_work_date', 'Date'),
    ('fr', 'hr.field_allocated', 'Alloués'),
    ('fr', 'hr.field_used', 'Pris'),
    ('fr', 'hr.field_remaining', 'Restants'),

    -- Stats
    ('fr', 'hr.stat_total', 'Total salariés'),
    ('fr', 'hr.stat_active', 'Actifs'),
    ('fr', 'hr.stat_on_leave', 'En absence'),
    ('fr', 'hr.stat_ongoing', 'En cours'),
    ('fr', 'hr.stat_pending', 'En attente'),
    ('fr', 'hr.stat_this_month', 'Ce mois'),
    ('fr', 'hr.stat_week_of', 'Semaine du'),
    ('fr', 'hr.stat_total_hours', 'Total heures'),
    ('fr', 'hr.stat_employees', 'Salariés'),
    ('fr', 'hr.stat_hours_30d', 'Heures (30j)'),

    -- Table headers
    ('fr', 'hr.col_employee', 'Salarié'),
    ('fr', 'hr.col_position', 'Poste'),
    ('fr', 'hr.col_department', 'Département'),
    ('fr', 'hr.col_contract', 'Contrat'),
    ('fr', 'hr.col_hire_date', 'Embauche'),
    ('fr', 'hr.col_status', 'Statut'),
    ('fr', 'hr.col_type', 'Type'),
    ('fr', 'hr.col_start', 'Début'),
    ('fr', 'hr.col_end', 'Fin'),
    ('fr', 'hr.col_days', 'Jours'),
    ('fr', 'hr.col_actions', 'Actions'),
    ('fr', 'hr.col_date', 'Date'),
    ('fr', 'hr.col_hours', 'Heures'),
    ('fr', 'hr.col_target', 'Objectif'),
    ('fr', 'hr.col_gender', 'Sexe'),
    ('fr', 'hr.col_nationality', 'Nationalité'),
    ('fr', 'hr.col_birth_date', 'Naissance'),
    ('fr', 'hr.col_job', 'Emploi'),
    ('fr', 'hr.col_qualification', 'Qualification'),
    ('fr', 'hr.col_entry', 'Entrée'),
    ('fr', 'hr.col_exit', 'Sortie'),
    ('fr', 'hr.col_employee_code', 'Matricule'),
    ('fr', 'hr.col_full_name', 'Nom Prénom'),

    -- Buttons / Actions
    ('fr', 'hr.btn_filter', 'Filtrer'),
    ('fr', 'hr.btn_new_employee', 'Nouveau salarié'),
    ('fr', 'hr.btn_save', 'Enregistrer'),
    ('fr', 'hr.btn_cancel', 'Annuler'),
    ('fr', 'hr.btn_edit', 'Modifier'),
    ('fr', 'hr.btn_delete', 'Supprimer'),
    ('fr', 'hr.btn_approve', 'Valider'),
    ('fr', 'hr.btn_reject', 'Refuser'),
    ('fr', 'hr.btn_declare', 'Déclarer'),

    -- Section titles
    ('fr', 'hr.title_profile', 'Fiche'),
    ('fr', 'hr.title_absences', 'Absences'),
    ('fr', 'hr.title_timesheets', 'Heures'),
    ('fr', 'hr.title_declare_absence', 'Déclarer une absence'),
    ('fr', 'hr.title_log_hours', 'Saisir des heures'),
    ('fr', 'hr.title_register', 'Registre du personnel'),
    ('fr', 'hr.title_register_notice', 'Registre obligatoire (Art. L1221-13 du Code du travail)'),

    -- Empty states
    ('fr', 'hr.empty_no_employee', 'Aucun salarié'),
    ('fr', 'hr.empty_first_employee', 'Ajoutez votre premier salarié pour commencer.'),
    ('fr', 'hr.empty_no_results', 'Aucun résultat pour ces filtres.'),
    ('fr', 'hr.empty_no_absence', 'Aucune absence enregistrée'),
    ('fr', 'hr.empty_no_absence_found', 'Aucune absence trouvée.'),
    ('fr', 'hr.empty_no_timesheet', 'Aucune heure saisie'),
    ('fr', 'hr.empty_no_active', 'Aucun salarié actif.'),

    -- Toast messages
    ('fr', 'hr.toast_employee_created', 'Salarié créé.'),
    ('fr', 'hr.toast_employee_updated', 'Salarié mis à jour.'),
    ('fr', 'hr.toast_employee_deleted', 'Salarié supprimé.'),
    ('fr', 'hr.toast_absence_declared', 'Absence déclarée.'),
    ('fr', 'hr.toast_timesheet_saved', 'Heures enregistrées.'),
    ('fr', 'hr.toast_balance_insufficient', 'Solde insuffisant.'),

    -- Error messages
    ('fr', 'hr.err_not_found', 'Salarié introuvable.'),
    ('fr', 'hr.err_name_required', 'Nom et prénom obligatoires.'),
    ('fr', 'hr.err_dates_required', 'Dates et nombre de jours obligatoires.'),
    ('fr', 'hr.err_date_order', 'La date de fin doit être après la date de début.'),
    ('fr', 'hr.err_hours_range', 'Heures entre 0 et 24.'),
    ('fr', 'hr.err_already_processed', 'Absence introuvable ou déjà traitée.'),

    -- Confirm dialogs
    ('fr', 'hr.confirm_delete_employee', 'Supprimer définitivement ce salarié et tout son historique ?'),

    -- Badge labels
    ('fr', 'hr.badge_ok', 'OK'),
    ('fr', 'hr.badge_partial', 'Partiel'),
    ('fr', 'hr.badge_empty', 'Vide'),

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
    ('fr', 'hr.field_absence_type', 'Type d''absence'),

    -- Confirm dialogs (_view)
    ('fr', 'hr.confirm_delete_absence', 'Supprimer cette absence ?'),
    ('fr', 'hr.confirm_delete_timesheet', 'Supprimer ce pointage ?')

  ON CONFLICT DO NOTHING;
END;
$function$;
