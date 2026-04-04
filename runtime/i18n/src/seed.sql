CREATE OR REPLACE FUNCTION i18n.seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO i18n.translation (lang, key, value) VALUES
    ('fr', 'sdui.issue_reported', 'Signalement envoyé, merci !'),
    ('fr', 'sdui.page_not_found', 'Page non trouvee'),
    ('fr', 'sdui.path_not_found', 'Le chemin %s n''existe pas.'),
    ('fr', 'sdui.error', 'Erreur'),
    ('fr', 'sdui.invalid_param', 'Parametre invalide'),
    ('fr', 'sdui.internal_error', 'Erreur interne'),
    ('fr', 'sdui.unexpected_error', 'Une erreur inattendue est survenue.'),
    ('fr', 'sdui.filter', 'Filtrer'),
    ('fr', 'sdui.filter_clear', 'Effacer'),
    ('fr', 'sdui.table_next', 'Suivant'),
    ('fr', 'sdui.table_prev', 'Précédent'),
    ('fr', 'sdui.table_empty', 'Aucun résultat'),
    ('fr', 'sdui.table_loading', 'Chargement…'),
    ('fr', 'sdui.table_search', 'Rechercher…'),
    ('fr', 'sdui.print', 'Télécharger SVG'),
    ('fr', 'app.group_main', 'Principal'),
    ('fr', 'app.group_commercial', 'Commercial'),
    ('fr', 'app.group_operations', 'Opérations'),
    ('fr', 'app.group_finance', 'Finance'),
    ('fr', 'app.group_team', 'Équipe'),
    ('fr', 'app.group_admin', 'Administration'),
    ('fr', 'app.search', 'Rechercher...'),
    ('fr', 'app.new', 'Nouveau'),
    ('fr', 'app.cancel', 'Annuler')
  ON CONFLICT (lang, key) DO UPDATE SET value = EXCLUDED.value;
END;
$function$;
