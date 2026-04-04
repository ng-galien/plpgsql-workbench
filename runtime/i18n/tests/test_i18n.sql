CREATE OR REPLACE FUNCTION i18n_ut.test_i18n()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Seed translations
  PERFORM i18n.seed();

  -- Default lang (fr) resolves known key
  PERFORM set_config('i18n.lang', 'fr', true);
  RETURN NEXT ok(i18n.t('sdui.error') = 'Erreur', 't() returns French value for known key');

  -- Missing key returns the key itself
  RETURN NEXT ok(i18n.t('nonexistent.key') = 'nonexistent.key', 't() returns key when not found');

  -- Unknown lang falls back to French
  PERFORM set_config('i18n.lang', 'de', true);
  RETURN NEXT ok(i18n.t('sdui.error') = 'Erreur', 't() falls back to fr for unknown lang');

  -- Empty lang setting defaults to fr
  PERFORM set_config('i18n.lang', '', true);
  RETURN NEXT ok(i18n.t('sdui.error') = 'Erreur', 't() defaults to fr when lang is empty');

  -- Unset lang defaults to fr
  PERFORM set_config('i18n.lang', '', true);
  RETURN NEXT ok(i18n.t('sdui.issue_reported') = 'Signalement envoyé, merci !', 't() resolves accented value');
END;
$function$;
