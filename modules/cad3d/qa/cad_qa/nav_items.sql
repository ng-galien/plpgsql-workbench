CREATE OR REPLACE FUNCTION cad_qa.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT '[
    {"href": "/", "label": "Dashboard"}
  ]'::jsonb;
$function$;
