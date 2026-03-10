CREATE OR REPLACE FUNCTION pgv.route(p_schema text, p_path text, p_body jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_nav jsonb;
  v_brand text;
  v_title text;
  v_fname text;
  v_body text;
  v_detail text;
  v_hint text;
BEGIN
  -- Get nav items
  EXECUTE format('SELECT %I.nav_items()', p_schema) INTO v_nav;

  -- Get brand (optional function, fallback to schema name)
  BEGIN
    EXECUTE format('SELECT %I.brand()', p_schema) INTO v_brand;
  EXCEPTION WHEN undefined_function THEN
    v_brand := initcap(p_schema);
  END;

  -- Derive function name from path
  IF p_path = '/' THEN
    v_fname := 'page_index';
  ELSE
    v_fname := 'page_' || replace(replace(trim(BOTH '/' FROM p_path), '/', '_'), '-', '_');
  END IF;

  -- Check function exists (introspection)
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = p_schema AND p.proname = v_fname
  ) THEN
    PERFORM set_config('response.status', '404', true);
    RETURN pgv.page(v_brand, '404', p_path, v_nav,
      pgv.error('404', 'Page non trouvee', 'Le chemin ' || p_path || ' n''existe pas.'));
  END IF;

  -- Find title from nav (href match)
  SELECT item->>'label' INTO v_title
  FROM jsonb_array_elements(v_nav) AS item
  WHERE item->>'href' = p_path;

  -- Fallback title from function name
  IF v_title IS NULL THEN
    v_title := initcap(replace(replace(v_fname, 'page_', ''), '_', ' '));
  END IF;

  -- Call the page function
  EXECUTE format('SELECT %I.%I()', p_schema, v_fname) INTO v_body;

  -- Wrap in page layout
  RETURN pgv.page(v_brand, v_title, p_path, v_nav, v_body);

EXCEPTION
  WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_detail = MESSAGE_TEXT, v_hint = PG_EXCEPTION_HINT;
    PERFORM set_config('response.status', '400', true);
    RETURN pgv.page(v_brand, 'Erreur', p_path, v_nav, pgv.error('400', 'Erreur', v_detail, v_hint));
  WHEN invalid_text_representation THEN
    GET STACKED DIAGNOSTICS v_detail = MESSAGE_TEXT;
    PERFORM set_config('response.status', '400', true);
    RETURN pgv.page(v_brand, 'Erreur', p_path, v_nav, pgv.error('400', 'Parametre invalide', v_detail));
  WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_detail = MESSAGE_TEXT;
    PERFORM set_config('response.status', '500', true);
    RETURN pgv.page(v_brand, 'Erreur', p_path, v_nav, pgv.error('500', 'Erreur interne', 'Une erreur inattendue est survenue.'));
END;
$function$;
