CREATE OR REPLACE FUNCTION app.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '[
    {"href": "/", "label": "Dashboard"},
    {"href": "/docs", "label": "Documents"},
    {"href": "/docs/search", "label": "Recherche"},
    {"href": "/settings", "label": "Config"}
  ]'::jsonb;
$function$;
