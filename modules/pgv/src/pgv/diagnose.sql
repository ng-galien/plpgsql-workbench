CREATE OR REPLACE FUNCTION pgv.diagnose(p_schema text, p_path text DEFAULT '/'::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_html text;
  v_start timestamptz;
  v_ms numeric;
  v_rows text := '';
  v_err int := 0;
  v_warn int := 0;
  v_ok int := 0;
  v_rec record;
  v_ns text;
  v_fn text;
  v_href text;
  v_params text[];
  v_inputs text[];
  v_missing text[];
  v_pages text[];
  v_page text;
  v_reports text := '';
  v_css_ok boolean;
BEGIN
  -- If path is '*', diagnose all nav pages
  IF p_path = '*' THEN
    BEGIN
      EXECUTE format(
        'SELECT array_agg(item->>''href'') FROM jsonb_array_elements(%I.nav_items()) AS item WHERE NOT (item->>''href'') ~ ''^https?://''',
        p_schema
      ) INTO v_pages;
    EXCEPTION WHEN OTHERS THEN
      -- nav_items() may return TABLE(label, href, icon) instead of jsonb
      EXECUTE format(
        'SELECT array_agg(href) FROM %I.nav_items() WHERE NOT href ~ ''^https?://''',
        p_schema
      ) INTO v_pages;
    END;
  ELSE
    v_pages := ARRAY[p_path];
  END IF;

  FOREACH v_page IN ARRAY v_pages LOOP
    v_rows := '';
    v_err := 0; v_warn := 0; v_ok := 0;

    -- Render page
    v_start := clock_timestamp();
    BEGIN
      v_html := pgv.route(p_schema, v_page, 'GET', '{}'::jsonb);
    EXCEPTION WHEN OTHERS THEN
      v_reports := v_reports || pgv.error('500', p_schema || ':' || v_page, SQLERRM) || chr(10);
      CONTINUE;
    END;
    v_ms := round(extract(epoch from clock_timestamp() - v_start) * 1000, 1);

    -- 1. Inline styles
    IF v_html ~ ' style\s*=\s*"' THEN
      v_rows := v_rows || '| ' || pgv.badge('ERR', 'danger') || ' | Style | inline `style` detecte |' || chr(10);
      v_err := v_err + 1;
    ELSE
      v_rows := v_rows || '| ' || pgv.badge('OK', 'success') || ' | Style | aucun inline style |' || chr(10);
      v_ok := v_ok + 1;
    END IF;

    -- 2. HTMX
    IF v_html ~ '\bhx-' THEN
      v_rows := v_rows || '| ' || pgv.badge('ERR', 'danger') || ' | HTMX | attributs hx-* detectes |' || chr(10);
      v_err := v_err + 1;
    ELSE
      v_rows := v_rows || '| ' || pgv.badge('OK', 'success') || ' | HTMX | aucun |' || chr(10);
      v_ok := v_ok + 1;
    END IF;

    -- 3. Raw <table> without <md>
    IF v_html ~ '<table[\s>]' AND v_html !~ '<md' THEN
      v_rows := v_rows || '| ' || pgv.badge('WARN', 'warning') || ' | Table | `<table>` sans `<md>` |' || chr(10);
      v_warn := v_warn + 1;
    END IF;

    -- 4. data-rpc targets
    FOR v_rec IN
      SELECT DISTINCT x[1] AS rpc FROM regexp_matches(v_html, 'data-rpc="([^"]+)"', 'g') t(x)
    LOOP
      IF v_rec.rpc LIKE '%.%' THEN
        v_ns := split_part(v_rec.rpc, '.', 1);
        v_fn := split_part(v_rec.rpc, '.', 2);
      ELSE
        v_ns := p_schema;
        v_fn := v_rec.rpc;
      END IF;

      IF EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = v_ns AND p.proname = v_fn
      ) THEN
        v_rows := v_rows || '| ' || pgv.badge('OK', 'success') || ' | RPC | `' || v_ns || '.' || v_fn || '()` |' || chr(10);
        v_ok := v_ok + 1;
      ELSE
        v_rows := v_rows || '| ' || pgv.badge('ERR', 'danger') || ' | RPC | `' || v_ns || '.' || v_fn || '()` introuvable |' || chr(10);
        v_err := v_err + 1;
      END IF;
    END LOOP;

    -- 5. Internal href targets
    FOR v_rec IN
      SELECT DISTINCT x[1] AS raw_href FROM regexp_matches(v_html, 'href="(/[^"]*)"', 'g') t(x)
    LOOP
      v_href := v_rec.raw_href;
      IF v_href LIKE '/' || p_schema || '/%' THEN
        v_href := substr(v_href, length(p_schema) + 2);
      ELSIF v_href = '/' || p_schema OR v_href = '/' || p_schema || '/' THEN
        v_href := '/';
      END IF;
      IF v_href LIKE '%?%' THEN v_href := split_part(v_href, '?', 1); END IF;

      v_fn := CASE WHEN v_href = '/' THEN 'get_index'
              ELSE 'get_' || replace(replace(trim(BOTH '/' FROM v_href), '/', '_'), '-', '_') END;

      IF EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = p_schema AND p.proname = v_fn
      ) THEN
        v_rows := v_rows || '| ' || pgv.badge('OK', 'success') || ' | Lien | `' || pgv.esc(v_rec.raw_href) || '` -> `' || v_fn || '()` |' || chr(10);
        v_ok := v_ok + 1;
      ELSE
        v_rows := v_rows || '| ' || pgv.badge('ERR', 'danger') || ' | Lien | `' || pgv.esc(v_rec.raw_href) || '` -> `' || v_fn || '()` introuvable |' || chr(10);
        v_err := v_err + 1;
      END IF;
    END LOOP;

    -- 6. <md> blocks valid
    FOR v_rec IN
      SELECT x[1] AS md_body FROM regexp_matches(v_html, '<md[^>]*>(.*?)</md>', 'g') t(x)
    LOOP
      IF v_rec.md_body ~ '^\s*\|.+\|\s*\n\s*\|[-| ]+\|' THEN
        v_rows := v_rows || '| ' || pgv.badge('OK', 'success') || ' | Markdown | bloc `<md>` valide |' || chr(10);
        v_ok := v_ok + 1;
      ELSE
        v_rows := v_rows || '| ' || pgv.badge('ERR', 'danger') || ' | Markdown | `<md>` sans header valide |' || chr(10);
        v_err := v_err + 1;
      END IF;
    END LOOP;

    -- 7. Form fields vs function signature
    FOR v_rec IN
      SELECT DISTINCT x[1] AS rpc FROM regexp_matches(v_html, '<form[^>]*data-rpc="([^"]+)"', 'g') t(x)
    LOOP
      SELECT proargnames INTO v_params
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = p_schema AND p.proname = v_rec.rpc
      LIMIT 1;

      IF v_params IS NOT NULL THEN
        v_inputs := ARRAY(
          SELECT DISTINCT x[1] FROM regexp_matches(v_html, 'name="([^"]+)"', 'g') t(x)
        );
        v_missing := ARRAY(
          SELECT unnest(v_params) EXCEPT SELECT unnest(v_inputs)
        );
        IF array_length(v_missing, 1) > 0 THEN
          v_rows := v_rows || '| ' || pgv.badge('WARN', 'warning') || ' | Form | `' || v_rec.rpc || '()` params sans champ: ' || array_to_string(v_missing, ', ') || ' |' || chr(10);
          v_warn := v_warn + 1;
        ELSE
          v_rows := v_rows || '| ' || pgv.badge('OK', 'success') || ' | Form | `' || v_rec.rpc || '()` signature couverte |' || chr(10);
          v_ok := v_ok + 1;
        END IF;
      END IF;
    END LOOP;

    -- 8. CSS class validation
    v_css_ok := true;
    FOR v_rec IN
      SELECT DISTINCT cls FROM (
        SELECT unnest(string_to_array(x[1], ' ')) AS cls
        FROM regexp_matches(v_html, 'class="([^"]*pgv-[^"]*)"', 'g') t(x)
      ) sub WHERE cls LIKE 'pgv-%'
    LOOP
      IF v_rec.cls NOT IN (
        'pgv-lazy','pgv-brand','pgv-burger-li','pgv-burger','pgv-nav-burger',
        'pgv-menu','pgv-menu-open',
        'pgv-badge','pgv-badge-success','pgv-badge-danger','pgv-badge-warning','pgv-badge-info','pgv-badge-primary',
        'pgv-stat','pgv-stat-value','pgv-dl','pgv-error',
        'pgv-alert','pgv-alert-success','pgv-alert-danger','pgv-alert-warning','pgv-alert-info',
        'pgv-empty','pgv-progress','pgv-avatar',
        'pgv-tabs','pgv-tabs-nav','pgv-accordion','pgv-breadcrumb',
        'pgv-tree','pgv-tree-icon','pgv-theme-toggle',
        'pgv-table','pgv-pager','pgv-pager-info','pgv-pager-btns','pgv-pager-dots',
        'pgv-sortable','pgv-canvas','pgv-canvas-vp','pgv-canvas-bar','pgv-canvas-btn','pgv-canvas-zoom','pgv-canvas-sep',
        'pgv-search-results','pgv-search-item','pgv-search-icon','pgv-search-body','pgv-search-more'
      ) THEN
        v_rows := v_rows || '| ' || pgv.badge('WARN', 'warning') || ' | CSS | classe `' || pgv.esc(v_rec.cls) || '` inconnue |' || chr(10);
        v_warn := v_warn + 1;
        v_css_ok := false;
      END IF;
    END LOOP;
    IF v_css_ok THEN
      v_rows := v_rows || '| ' || pgv.badge('OK', 'success') || ' | CSS | toutes les classes pgv-* connues |' || chr(10);
      v_ok := v_ok + 1;
    END IF;

    -- Page report
    v_reports := v_reports || pgv.dl(
      'Page', p_schema || ' : ' || v_page,
      'Rendu', v_ms || ' ms',
      'Bilan',
        CASE WHEN v_err > 0 THEN pgv.badge(v_err || ' erreur(s)', 'danger') || ' ' ELSE '' END
        || CASE WHEN v_warn > 0 THEN pgv.badge(v_warn || ' warning(s)', 'warning') || ' ' ELSE '' END
        || pgv.badge(v_ok || ' ok', 'success'))
      || '<md>' || chr(10)
      || '| Niveau | Check | Detail |' || chr(10)
      || '|--------|-------|--------|' || chr(10)
      || v_rows
      || '</md>' || chr(10);

  END LOOP;

  RETURN v_reports;
END;
$function$;
