CREATE OR REPLACE FUNCTION app.page(p_path text, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_detail text;
  v_hint text;
BEGIN
  CASE
    WHEN p_path = '/' THEN
      RETURN pgv.page('Dashboard', '/', app.nav_items(),
        pgv.grid(
          pgv.stat('Documents',
            (SELECT count(*)::text FROM docman.document), 'total'),
          pgv.stat('Non classes',
            (SELECT count(*)::text FROM docman.document WHERE classified_at IS NULL), 'a traiter'),
          pgv.stat('Labels',
            (SELECT count(*)::text FROM docman.label), 'actifs')
        )
      );
    WHEN p_path LIKE '/docs%' THEN
      RETURN docman.page(p_path, p_body);
    WHEN p_path = '/settings' THEN
      RETURN app.page_settings(p_body);
    ELSE
      PERFORM set_config('response.status', '404', true);
      RETURN pgv.page('404', p_path, app.nav_items(),
        pgv.error('404', 'Page non trouvee', 'Le chemin ' || p_path || ' n''existe pas.'));
  END CASE;

EXCEPTION
  WHEN raise_exception THEN
    -- Application errors (RAISE from business logic)
    GET STACKED DIAGNOSTICS v_detail = MESSAGE_TEXT, v_hint = PG_EXCEPTION_HINT;
    PERFORM set_config('response.status', '400', true);
    RETURN pgv.page('Erreur', p_path, app.nav_items(),
      pgv.error('400', 'Erreur', v_detail, v_hint));

  WHEN no_data_found THEN
    PERFORM set_config('response.status', '404', true);
    RETURN pgv.page('Introuvable', p_path, app.nav_items(),
      pgv.error('404', 'Ressource introuvable', 'Aucun resultat pour ' || p_path));

  WHEN invalid_text_representation THEN
    -- Bad UUID, bad parameter format
    GET STACKED DIAGNOSTICS v_detail = MESSAGE_TEXT;
    PERFORM set_config('response.status', '400', true);
    RETURN pgv.page('Erreur', p_path, app.nav_items(),
      pgv.error('400', 'Parametre invalide', v_detail, 'Verifiez le format des parametres (UUID, etc.)'));

  WHEN OTHERS THEN
    -- Unexpected errors — don't leak internals
    GET STACKED DIAGNOSTICS v_detail = MESSAGE_TEXT;
    RAISE WARNING 'app.page error: % (path: %)', v_detail, p_path;
    PERFORM set_config('response.status', '500', true);
    RETURN pgv.page('Erreur', p_path, app.nav_items(),
      pgv.error('500', 'Erreur interne', 'Une erreur inattendue est survenue.', 'Contactez l''administrateur si le probleme persiste.'));
END;
$function$;
