CREATE OR REPLACE FUNCTION catalog.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
SELECT jsonb_build_array(
    jsonb_build_object('label', 'Articles',    'href', '/articles'),
    jsonb_build_object('label', 'Catégories',  'href', '/categories')
);
$function$;
