CREATE OR REPLACE FUNCTION pgv.ui_datasource(p_uri text, p_page_size integer DEFAULT 20, p_searchable boolean DEFAULT false, p_default_sort text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('uri', p_uri, 'page_size', p_page_size, 'searchable', p_searchable)
    || CASE WHEN p_default_sort IS NOT NULL THEN jsonb_build_object('default_sort', p_default_sort) ELSE '{}'::jsonb END;
$function$;
