CREATE OR REPLACE FUNCTION pgv_qa.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT '[
    {"href": "/", "label": "Dashboard"},
    {"href": "/atoms", "label": "Composants"},
    {"href": "/tables", "label": "Tables"},
    {"href": "/forms", "label": "Formulaires"},
    {"href": "/dialogs", "label": "Dialogs"},
    {"href": "/toast", "label": "Toasts"},
    {"href": "/errors", "label": "Erreurs"},
    {"href": "/settings", "label": "Config"}
  ]'::jsonb;
$function$;
