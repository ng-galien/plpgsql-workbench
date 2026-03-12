CREATE OR REPLACE FUNCTION pgv.route(p_schema text, p_path text, p_method text DEFAULT 'GET'::text, p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS "text/html"
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_nav jsonb;
  v_opts jsonb;
  v_brand text;
  v_title text;
  v_fname text;
  v_body text;
  v_detail text;
  v_hint text;
  v_route text;
  v_nargs int;
  v_argtype text;
  v_argname text;
BEGIN
  -- Set i18n language for this request
  PERFORM set_config('pgv.lang', coalesce(nullif(current_setting('pgv.lang', true), ''), 'fr'), true);

  -- Get nav items
  BEGIN
    EXECUTE format('SELECT %I.nav_items()', p_schema) INTO v_nav;
  EXCEPTION WHEN undefined_function THEN
    RAISE EXCEPTION 'Module % has no nav_items() function', p_schema;
  END;

  -- Get brand (optional, fallback to schema name)
  BEGIN
    EXECUTE format('SELECT %I.brand()', p_schema) INTO v_brand;
  EXCEPTION WHEN undefined_function THEN
    v_brand := initcap(p_schema);
  END;

  -- Get nav options (optional, fallback to empty)
  BEGIN
    EXECUTE format('SELECT %I.nav_options()', p_schema) INTO v_opts;
  EXCEPTION WHEN undefined_function THEN
    v_opts := '{}'::jsonb;
  END;

  -- Derive function name: method + path
  IF p_path = '/' THEN
    v_fname := lower(p_method) || '_index';
  ELSE
    v_fname := lower(p_method) || '_' || replace(replace(trim(BOTH '/' FROM p_path), '/', '_'), '-', '_');
  END IF;

  -- Full route path
  v_route := '/' || p_schema || p_path;

  -- Set route prefix early (pgv.call_ref() needs it)
  PERFORM set_config('pgv.route_prefix', '/' || p_schema, true);

  -- Prefix nav hrefs with schema
  v_nav := (
    SELECT jsonb_agg(
      CASE WHEN (item->>'href') ~ '^https?://'
        THEN item
        ELSE jsonb_set(item, '{href}', to_jsonb('/' || p_schema || (item->>'href')))
      END
    )
    FROM jsonb_array_elements(v_nav) AS item
  );

  -- Introspect function signature (max 1 arg)
  SELECT p.pronargs,
         CASE WHEN p.pronargs > 0 THEN (p.proargtypes::oid[])[0]::regtype::text END,
         CASE WHEN p.pronargs > 0 THEN p.proargnames[1] END
  INTO v_nargs, v_argtype, v_argname
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = p_schema AND p.proname = v_fname AND p.prokind = 'f'
    AND p.pronargs <= 1;

  IF NOT FOUND THEN
    -- GET: return 200 with error page (shell renders HTML, no need for HTTP error)
    -- POST: return 404 so shell shows toast via _err()
    IF lower(p_method) = 'post' THEN
      PERFORM set_config('response.status', '404', true);
      RETURN '<template data-toast="error">Page non trouvee: ' || pgv.esc(p_method || ' ' || p_path) || '</template>';
    END IF;
    RETURN pgv.page(v_brand, '404', v_route, v_nav,
      pgv.error('404', 'Page non trouvee', 'Le chemin ' || p_method || ' ' || p_path || ' n''existe pas.'), v_opts);
  END IF;

  -- Execute based on signature
  IF v_nargs = 0 THEN
    EXECUTE format('SELECT %I.%I()', p_schema, v_fname) INTO v_body;
  ELSIF v_argtype = 'jsonb' THEN
    EXECUTE format('SELECT %I.%I($1)', p_schema, v_fname) USING p_params INTO v_body;
  ELSIF v_argtype IN ('integer', 'bigint', 'text', 'uuid') THEN
    EXECUTE format('SELECT %I.%I($1::%s)', p_schema, v_fname, v_argtype)
      USING p_params->>v_argname INTO v_body;
  ELSE
    -- Composite type: deserialize jsonb into typed record
    EXECUTE format('SELECT %I.%I(jsonb_populate_record(NULL::%s, $1))', p_schema, v_fname, v_argtype)
      USING p_params INTO v_body;
  END IF;

  -- POST: return raw (toast/redirect templates, no layout)
  IF lower(p_method) = 'post' THEN
    RETURN v_body;
  END IF;

  -- GET: find title from nav
  SELECT item->>'label' INTO v_title
  FROM jsonb_array_elements(v_nav) AS item
  WHERE item->>'href' = v_route;

  IF v_title IS NULL THEN
    v_title := initcap(replace(regexp_replace(v_fname, '^(get|post)_', ''), '_', ' '));
  END IF;

  -- Wrap in page layout
  RETURN pgv.page(v_brand, v_title, v_route, v_nav, v_body, v_opts);

EXCEPTION
  WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_detail = MESSAGE_TEXT, v_hint = PG_EXCEPTION_HINT;
    PERFORM set_config('pgv.route_prefix', '/' || p_schema, true);
    IF lower(p_method) = 'post' THEN
      PERFORM set_config('response.status', '400', true);
      RETURN '<template data-toast="error">' || pgv.esc(v_detail) || '</template>';
    END IF;
    RETURN pgv.page(v_brand, 'Erreur', v_route, v_nav, pgv.error('400', 'Erreur', v_detail, v_hint), v_opts);
  WHEN invalid_text_representation THEN
    GET STACKED DIAGNOSTICS v_detail = MESSAGE_TEXT;
    PERFORM set_config('pgv.route_prefix', '/' || p_schema, true);
    IF lower(p_method) = 'post' THEN
      PERFORM set_config('response.status', '400', true);
      RETURN '<template data-toast="error">' || pgv.esc(v_detail) || '</template>';
    END IF;
    RETURN pgv.page(v_brand, 'Erreur', v_route, v_nav, pgv.error('400', 'Parametre invalide', v_detail), v_opts);
  WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_detail = MESSAGE_TEXT;
    PERFORM set_config('pgv.route_prefix', '/' || p_schema, true);
    IF lower(p_method) = 'post' THEN
      PERFORM set_config('response.status', '500', true);
      RETURN '<template data-toast="error">Erreur interne</template>';
    END IF;
    RETURN pgv.page(v_brand, 'Erreur', v_route, v_nav, pgv.error('500', 'Erreur interne', 'Une erreur inattendue est survenue.'), v_opts);
END;
$function$;
