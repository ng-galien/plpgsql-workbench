CREATE OR REPLACE FUNCTION pgv.i18n_seed()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO pgv.i18n (lang, key, value) VALUES
    ('fr', 'pgv.issue_reported', 'Signalement envoyé, merci !'),
    ('fr', 'pgv.page_not_found', 'Page non trouvee'),
    ('fr', 'pgv.path_not_found', 'Le chemin %s n''existe pas.'),
    ('fr', 'pgv.error', 'Erreur'),
    ('fr', 'pgv.invalid_param', 'Parametre invalide'),
    ('fr', 'pgv.internal_error', 'Erreur interne'),
    ('fr', 'pgv.unexpected_error', 'Une erreur inattendue est survenue.'),
    ('fr', 'pgv.filter', 'Filtrer'),
    ('fr', 'pgv.filter_clear', 'Effacer'),
    ('fr', 'pgv.table_next', 'Suivant'),
    ('fr', 'pgv.table_prev', 'Précédent'),
    ('fr', 'pgv.table_empty', 'Aucun résultat'),
    ('fr', 'pgv.table_loading', 'Chargement…'),
    ('fr', 'pgv.table_search', 'Rechercher…'),
    ('fr', 'pgv.print', 'Télécharger SVG')
  ON CONFLICT (lang, key) DO UPDATE SET value = EXCLUDED.value;
END;
$function$;
