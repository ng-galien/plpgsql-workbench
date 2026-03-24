CREATE OR REPLACE FUNCTION catalog.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
SELECT jsonb_build_array(
    jsonb_build_object('label', pgv.t('catalog.nav_articles'),    'href', '/articles', 'entity', 'article'),
    jsonb_build_object('label', pgv.t('catalog.nav_categories'),  'href', '/categories', 'entity', 'categorie')
);
$function$;
