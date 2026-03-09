CREATE OR REPLACE FUNCTION app.page(p_path text, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
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
      RETURN pgv.page('404', p_path, app.nav_items(),
        '<p>Page non trouvee : <code>' || pgv.esc(p_path) || '</code></p>');
  END CASE;
END;
$function$;
