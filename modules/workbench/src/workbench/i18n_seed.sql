CREATE OR REPLACE FUNCTION workbench.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n(lang, key, value) VALUES
    ('fr', 'workbench.brand', 'Workbench'),
    ('fr', 'workbench.nav_messages', 'Messages'),
    ('fr', 'workbench.nav_issues', 'Issues'),
    ('fr', 'workbench.nav_tools', 'Outils'),
    ('fr', 'workbench.nav_primitives', 'Primitives'),
    -- Stats
    ('fr', 'workbench.stat_new_msg', 'Nouveaux'),
    ('fr', 'workbench.stat_new_msg_detail', 'messages non lus'),
    ('fr', 'workbench.stat_pending', 'En cours'),
    ('fr', 'workbench.stat_pending_detail', 'messages en attente'),
    ('fr', 'workbench.stat_issues', 'Issues'),
    ('fr', 'workbench.stat_issues_detail', 'ouvertes'),
    ('fr', 'workbench.stat_tools', 'Outils'),
    ('fr', 'workbench.stat_tools_detail', 'disponibles'),
    ('fr', 'workbench.stat_related_messages', 'Messages lies'),
    ('fr', 'workbench.stat_replies', 'Reponses'),
    -- Titles
    ('fr', 'workbench.title_recent_msg', 'Messages recents'),
    ('fr', 'workbench.title_open_issues', 'Issues ouvertes'),
    ('fr', 'workbench.title_messages', 'Messages'),
    ('fr', 'workbench.title_issues', 'Issues'),
    ('fr', 'workbench.title_tools', 'Outils'),
    ('fr', 'workbench.title_tool_detail', 'Detail outil'),
    ('fr', 'workbench.title_message_detail', 'Detail message'),
    -- Buttons
    ('fr', 'workbench.btn_back_messages', 'Retour messages'),
    ('fr', 'workbench.btn_back_tools', 'Retour outils'),
    -- Labels
    ('fr', 'workbench.label_no_messages', 'Aucun message'),
    ('fr', 'workbench.label_no_issues', 'Aucune issue ouverte'),
    ('fr', 'workbench.label_no_tools', 'Aucun outil enregistre'),
    -- Entity labels
    ('fr', 'workbench.entity_issue_report', 'Issue'),
    ('fr', 'workbench.entity_agent_message', 'Message'),
    -- Related
    ('fr', 'workbench.rel_dispatch_message', 'Message de dispatch'),
    ('fr', 'workbench.rel_related_messages', 'Messages lies'),
    ('fr', 'workbench.rel_linked_issue', 'Issue liee'),
    ('fr', 'workbench.rel_thread', 'Fil de discussion'),
    -- Form sections
    ('fr', 'workbench.section_issue_info', 'Informations'),
    ('fr', 'workbench.section_message_info', 'Informations'),
    -- Form fields
    ('fr', 'workbench.field_issue_type', 'Type'),
    ('fr', 'workbench.field_module', 'Module'),
    ('fr', 'workbench.field_description', 'Description'),
    ('fr', 'workbench.field_status', 'Statut'),
    ('fr', 'workbench.field_to', 'Destinataire'),
    ('fr', 'workbench.field_msg_type', 'Type'),
    ('fr', 'workbench.field_priority', 'Priorite'),
    ('fr', 'workbench.field_subject', 'Sujet'),
    ('fr', 'workbench.field_body', 'Corps'),
    -- Actions
    ('fr', 'workbench.action_acknowledge', 'Prendre en charge'),
    ('fr', 'workbench.action_resolve', 'Resoudre'),
    ('fr', 'workbench.action_close', 'Fermer'),
    ('fr', 'workbench.action_reopen', 'Rouvrir'),
    ('fr', 'workbench.action_delete', 'Supprimer'),
    -- Confirmations
    ('fr', 'workbench.confirm_delete_issue', 'Supprimer cette issue ?'),
    ('fr', 'workbench.confirm_delete_message', 'Supprimer ce message ?')
  ON CONFLICT DO NOTHING;
END;
$function$;
