CREATE OR REPLACE FUNCTION docman.page(p_path text, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_sub text;
  v_uuid uuid;
BEGIN
  -- Strip /docs prefix
  v_sub := regexp_replace(p_path, '^/docs/?', '');

  -- /docs or /docs/ -> inbox
  IF v_sub = '' THEN
    RETURN docman.page_inbox();
  END IF;

  -- /docs/search
  IF v_sub = 'search' THEN
    RETURN docman.page_search();
  END IF;

  -- /docs/:uuid/classify
  IF v_sub ~ '^[0-9a-f-]{36}/classify$' THEN
    v_uuid := left(v_sub, 36)::uuid;
    RETURN docman.page_classify(v_uuid, p_body);
  END IF;

  -- /docs/:uuid
  IF v_sub ~ '^[0-9a-f-]{36}$' THEN
    v_uuid := v_sub::uuid;
    RETURN docman.page_detail(v_uuid);
  END IF;

  -- Fallback
  RETURN pgv.page('404', p_path, app.nav_items(),
    '<p>Page non trouvee : <code>' || pgv.esc(p_path) || '</code></p>');
END;
$function$;
