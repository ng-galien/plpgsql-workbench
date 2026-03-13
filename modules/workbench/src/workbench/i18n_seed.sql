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
    ('fr', 'workbench.stat_new_msg', 'Nouveaux'),
    ('fr', 'workbench.stat_new_msg_detail', 'messages non lus'),
    ('fr', 'workbench.stat_pending', 'En cours'),
    ('fr', 'workbench.stat_pending_detail', 'messages en attente'),
    ('fr', 'workbench.stat_issues', 'Issues'),
    ('fr', 'workbench.stat_issues_detail', 'ouvertes'),
    ('fr', 'workbench.stat_tools', 'Outils'),
    ('fr', 'workbench.stat_tools_detail', 'disponibles'),
    ('fr', 'workbench.title_recent_msg', 'Messages recents'),
    ('fr', 'workbench.title_open_issues', 'Issues ouvertes'),
    ('fr', 'workbench.title_messages', 'Messages'),
    ('fr', 'workbench.title_issues', 'Issues'),
    ('fr', 'workbench.title_tools', 'Outils'),
    ('fr', 'workbench.title_tool_detail', 'Detail outil'),
    ('fr', 'workbench.btn_back_messages', 'Retour messages'),
    ('fr', 'workbench.btn_back_tools', 'Retour outils'),
    ('fr', 'workbench.label_no_messages', 'Aucun message'),
    ('fr', 'workbench.label_no_issues', 'Aucune issue ouverte'),
    ('fr', 'workbench.label_no_tools', 'Aucun outil enregistre'),
    ('fr', 'workbench.title_message_detail', 'Detail message')
  ON CONFLICT DO NOTHING;
END;
$function$;
