-- app schema: application router and navigation
-- Depends on: pgv schema (004_pgv.sql)

CREATE OR REPLACE FUNCTION app.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '[
    {"href": "/", "label": "Dashboard"},
    {"href": "/docs", "label": "Documents"},
    {"href": "/docs/search", "label": "Recherche"}
  ]'::jsonb;
$function$;

CREATE OR REPLACE FUNCTION app.page_stub(p_path text, p_section text)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN pgv.page(p_section, p_path, app.nav_items(),
    pgv.card(null,
      '<p>Page <code>' || pgv.esc(p_path) || '</code> en construction.</p>'
      || '<p><a href="/" hx-get="/rpc/page?p_path=/" hx-push-url="/">Retour au dashboard</a></p>'
    )
  );
END;
$function$;

CREATE OR REPLACE FUNCTION app.page(p_path text, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
BEGIN
  CASE
    WHEN p_path = '/' THEN
      RETURN pgv.page('Dashboard', '/', app.nav_items(),
        pgv.grid(
          pgv.stat('Documents', '0', 'total'),
          pgv.stat('Non classes', '0', 'a traiter'),
          pgv.stat('Labels', '0', 'actifs')
        )
      );
    WHEN p_path LIKE '/docs%' THEN
      RETURN app.page_stub(p_path, 'Documents');
    ELSE
      RETURN pgv.page('404', p_path, app.nav_items(),
        '<p>Page non trouvee : <code>' || pgv.esc(p_path) || '</code></p>');
  END CASE;
END;
$function$;

-- Grants --------------------------------------------------------------

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO web_anon;
