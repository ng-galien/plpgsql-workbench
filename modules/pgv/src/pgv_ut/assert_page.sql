CREATE OR REPLACE FUNCTION pgv_ut.assert_page(p_html text, p_schema text DEFAULT NULL::text)
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rpc text;
  v_schema text;
  v_fname text;
  v_href text;
  v_page_fn text;
  v_match text[];
  v_errors int := 0;
BEGIN
  -- 1. No inline styles
  IF p_html ~ 'style\s*=\s*"' THEN
    v_errors := v_errors + 1;
    RETURN NEXT ok(false, 'no inline styles (style="...")');
  ELSE
    RETURN NEXT ok(true, 'no inline styles');
  END IF;

  -- 2. All data-rpc point to existing functions
  FOR v_match IN
    SELECT regexp_matches(p_html, 'data-rpc="([^"]+)"', 'g')
  LOOP
    v_rpc := v_match[1];
    -- data-rpc may be "schema.fn" or just "fn" (resolved via p_schema)
    IF v_rpc LIKE '%.%' THEN
      v_schema := split_part(v_rpc, '.', 1);
      v_fname := split_part(v_rpc, '.', 2);
    ELSIF p_schema IS NOT NULL THEN
      v_schema := p_schema;
      v_fname := v_rpc;
    ELSE
      -- Cannot resolve without schema context — skip
      RETURN NEXT ok(true, format('data-rpc "%s" (schema unknown, skipped)', v_rpc));
      CONTINUE;
    END IF;

    IF EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = v_schema AND p.proname = v_fname
    ) THEN
      RETURN NEXT ok(true, format('data-rpc "%s" -> %s.%s() exists', v_rpc, v_schema, v_fname));
    ELSE
      v_errors := v_errors + 1;
      RETURN NEXT ok(false, format('data-rpc "%s" -> %s.%s() NOT FOUND', v_rpc, v_schema, v_fname));
    END IF;
  END LOOP;

  -- 3. All href="/path" resolve to page_* functions (if schema known)
  IF p_schema IS NOT NULL THEN
    FOR v_match IN
      SELECT regexp_matches(p_html, 'href="(/[^"]*)"', 'g')
    LOOP
      v_href := v_match[1];
      -- Skip anchors and external
      IF v_href LIKE '#%' OR v_href LIKE 'http%' THEN
        CONTINUE;
      END IF;
      -- Derive expected function: /foo/bar -> page_foo_bar
      IF v_href = '/' THEN
        v_page_fn := 'page_index';
      ELSE
        v_page_fn := 'page_' || replace(replace(trim(BOTH '/' FROM v_href), '/', '_'), '-', '_');
      END IF;
      -- Strip numeric segments for parametric routes (e.g. /drawing/3/3d -> page_drawing_3d)
      v_page_fn := regexp_replace(v_page_fn, '_\d+', '', 'g');

      IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = p_schema AND p.proname = v_page_fn
      ) THEN
        RETURN NEXT ok(true, format('href "%s" -> %s.%s() exists', v_href, p_schema, v_page_fn));
      ELSE
        v_errors := v_errors + 1;
        RETURN NEXT ok(false, format('href "%s" -> %s.%s() NOT FOUND', v_href, p_schema, v_page_fn));
      END IF;
    END LOOP;
  END IF;

  -- 4. <md> blocks contain valid markdown table headers
  FOR v_match IN
    SELECT regexp_matches(p_html, '<md[^>]*>([\s\S]*?)</md>', 'g')
  LOOP
    IF v_match[1] ~ '^\s*\|.+\|\s*\n\s*\|[-| ]+\|' THEN
      RETURN NEXT ok(true, 'md block has valid table header');
    ELSE
      v_errors := v_errors + 1;
      RETURN NEXT ok(false, 'md block missing table header (| col | ... | + separator)');
    END IF;
  END LOOP;

  -- 5. Summary
  IF v_errors = 0 THEN
    RETURN NEXT ok(true, format('page contract valid (%s checks passed)', v_errors));
  END IF;
END;
$function$;
