CREATE OR REPLACE FUNCTION docman.page_search()
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_types jsonb;
  v_body text;
BEGIN
  -- Collect known doc_types for filter select
  SELECT coalesce(jsonb_agg(to_jsonb(dt.doc_type)), '[]'::jsonb)
  INTO v_types
  FROM (SELECT DISTINCT doc_type FROM docman.document WHERE doc_type IS NOT NULL ORDER BY doc_type) dt;

  v_body := pgv.card('Filtres',
    '<form hx-post="/rpc/frag_search" hx-target="#search-results" hx-swap="innerHTML">'
      || '<div class="grid">'
      || pgv.input('q', 'search', 'Recherche texte')
      || pgv.sel('doc_type', 'Type', v_types)
      || pgv.sel('source', 'Source', '["filesystem", "email"]'::jsonb)
      || '</div>'
      || '<button type="submit">Rechercher</button>'
      || '</form>'
  );

  v_body := v_body || '<div id="search-results"></div>';

  RETURN pgv.page('Recherche', '/docs/search', app.nav_items(), v_body);
END;
$function$;
