CREATE OR REPLACE FUNCTION pgv_ut.test_i18n()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Seed translations
  PERFORM pgv.i18n_seed();

  -- Default lang (fr) resolves known key
  PERFORM set_config('pgv.lang', 'fr', true);
  RETURN NEXT ok(pgv.t('pgv.error') = 'Erreur', 't() returns French value for known key');

  -- Missing key returns the key itself
  RETURN NEXT ok(pgv.t('nonexistent.key') = 'nonexistent.key', 't() returns key when not found');

  -- Unknown lang falls back to French
  PERFORM set_config('pgv.lang', 'de', true);
  RETURN NEXT ok(pgv.t('pgv.error') = 'Erreur', 't() falls back to fr for unknown lang');

  -- Empty lang setting defaults to fr
  PERFORM set_config('pgv.lang', '', true);
  RETURN NEXT ok(pgv.t('pgv.error') = 'Erreur', 't() defaults to fr when lang is empty');

  -- Unset lang defaults to fr
  PERFORM set_config('pgv.lang', '', true);
  RETURN NEXT ok(pgv.t('pgv.bug_reported') = 'Bug reporté, merci !', 't() resolves accented value');
END;
$function$;
