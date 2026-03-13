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
    ('fr', 'pgv.unexpected_error', 'Une erreur inattendue est survenue.')
  ON CONFLICT (lang, key) DO UPDATE SET value = EXCLUDED.value;
END;
$function$;
