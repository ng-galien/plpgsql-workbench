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
  v_path_only text;
  v_params_jsonb jsonb;
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

    -- Parse query params from path
    v_params_jsonb := '{}'::jsonb;
    IF v_page LIKE '%?%' THEN
      v_path_only := split_part(v_page, '?', 1);
      FOR v_rec IN
        SELECT split_part(pair, '=', 1) AS k, split_part(pair, '=', 2) AS v
        FROM unnest(string_to_array(split_part(v_page, '?', 2), '&')) AS pair
      LOOP
        v_params_jsonb := v_params_jsonb || jsonb_build_object(v_rec.k, v_rec.v);
      END LOOP;
    ELSE
      v_path_only := v_page;
    END IF;

    -- Render page
    v_start := clock_timestamp();
    BEGIN
      v_html := pgv.route(p_schema, v_path_only, 'GET', v_params_jsonb);
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
      -- Shell routes POST via pgv.route(): post_ + rpc_without_post_
      v_fn := 'post_' || regexp_replace(v_fn, '^post_', '');

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

    -- 5. Internal href targets (cross-module aware)
    FOR v_rec IN
      SELECT DISTINCT x[1] AS raw_href FROM regexp_matches(v_html, 'href="(/[^"]*)"', 'g') t(x)
    LOOP
      v_href := v_rec.raw_href;
      -- Strip query params for resolution
      IF v_href LIKE '%?%' THEN v_href := split_part(v_href, '?', 1); END IF;

      -- Detect target schema from first path segment
      v_ns := split_part(trim(LEADING '/' FROM v_href), '/', 1);
      IF v_ns <> p_schema AND EXISTS (
        SELECT 1 FROM pg_namespace WHERE nspname = v_ns
      ) THEN
        -- Cross-module link: /crm/client -> crm.get_client()
        v_fn := CASE
          WHEN trim(BOTH '/' FROM substr(v_href, length(v_ns) + 2)) = '' THEN 'get_index'
          ELSE 'get_' || replace(replace(trim(BOTH '/' FROM substr(v_href, length(v_ns) + 2)), '/', '_'), '-', '_')
        END;
      ELSE
        -- Same-module link: strip schema prefix if present
        IF v_href LIKE '/' || p_schema || '/%' THEN
          v_href := substr(v_href, length(p_schema) + 2);
        ELSIF v_href = '/' || p_schema OR v_href = '/' || p_schema || '/' THEN
          v_href := '/';
        END IF;
        v_ns := p_schema;
        v_fn := CASE WHEN v_href = '/' THEN 'get_index'
                ELSE 'get_' || replace(replace(trim(BOTH '/' FROM v_href), '/', '_'), '-', '_') END;
      END IF;

      IF EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = v_ns AND p.proname = v_fn
      ) THEN
        v_rows := v_rows || '| ' || pgv.badge('OK', 'success') || ' | Lien | `' || pgv.esc(v_rec.raw_href) || '` -> `' || v_ns || '.' || v_fn || '()` |' || chr(10);
        v_ok := v_ok + 1;
      ELSE
        v_rows := v_rows || '| ' || pgv.badge('ERR', 'danger') || ' | Lien | `' || pgv.esc(v_rec.raw_href) || '` -> `' || v_ns || '.' || v_fn || '()` introuvable |' || chr(10);
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
      WHERE n.nspname = p_schema AND p.proname = 'post_' || regexp_replace(v_rec.rpc, '^post_', '')
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

  -- 9. Static RPC analysis (schema-wide, source code scan)
  v_rows := '';
  v_err := 0; v_ok := 0; v_warn := 0;
  FOR v_rec IN
    WITH rpc_refs AS (
      -- data-rpc="xxx" in function bodies
      SELECT p.proname AS source,
             (regexp_matches(pg_get_functiondef(p.oid), 'data-rpc="([^"]+)"', 'g'))[1] AS rpc
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = p_schema
      UNION
      -- pgv.action('xxx', ...) calls
      SELECT p.proname AS source,
             (regexp_matches(pg_get_functiondef(p.oid), E'pgv\\.action\\(''([^'']+)''', 'g'))[1] AS rpc
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = p_schema
    ),
    resolved AS (
      SELECT DISTINCT r.source, r.rpc,
             CASE WHEN r.rpc LIKE '%.%' THEN split_part(r.rpc, '.', 1) ELSE p_schema END AS target_schema,
             'post_' || regexp_replace(
               CASE WHEN r.rpc LIKE '%.%' THEN split_part(r.rpc, '.', 2) ELSE r.rpc END,
               '^post_', ''
             ) AS target_fn
      FROM rpc_refs r
    )
    SELECT r.source, r.rpc, r.target_schema, r.target_fn,
           EXISTS (
             SELECT 1 FROM pg_proc p2 JOIN pg_namespace n2 ON n2.oid = p2.pronamespace
             WHERE n2.nspname = r.target_schema AND p2.proname = r.target_fn
           ) AS found
    FROM resolved r
    ORDER BY found, r.source, r.rpc
  LOOP
    IF v_rec.found THEN
      v_ok := v_ok + 1;
    ELSE
      v_rows := v_rows || '| ' || pgv.badge('ERR', 'danger') || ' | ' || pgv.esc(v_rec.source) || ' | `' || v_rec.rpc || '` -> `' || v_rec.target_schema || '.' || v_rec.target_fn || '()` introuvable |' || chr(10);
      v_err := v_err + 1;
    END IF;
  END LOOP;

  IF v_err > 0 OR v_ok > 0 THEN
    v_reports := v_reports || pgv.dl(
      'Analyse statique RPC', p_schema,
      'Bilan',
        CASE WHEN v_err > 0 THEN pgv.badge(v_err || ' mort(s)', 'danger') || ' ' ELSE '' END
        || pgv.badge(v_ok || ' ok', 'success'))
      || '<md>' || chr(10)
      || '| Niveau | Source | Detail |' || chr(10)
      || '|--------|--------|--------|' || chr(10)
      || v_rows
      || '</md>' || chr(10);
  END IF;

  -- 10. Dead post_* functions (exist but never referenced by data-rpc or pgv.action)
  v_rows := '';
  v_warn := 0;
  FOR v_rec IN
    WITH rpc_refs AS (
      SELECT (regexp_matches(pg_get_functiondef(p.oid), 'data-rpc="([^"]+)"', 'g'))[1] AS rpc
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = p_schema
      UNION
      SELECT (regexp_matches(pg_get_functiondef(p.oid), E'pgv\\.action\\(''([^'']+)''', 'g'))[1] AS rpc
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = p_schema
    ),
    referenced AS (
      SELECT DISTINCT 'post_' || regexp_replace(
        CASE WHEN rpc LIKE '%.%' THEN split_part(rpc, '.', 2) ELSE rpc END,
        '^post_', ''
      ) AS fn
      FROM rpc_refs
    ),
    all_posts AS (
      SELECT p.proname
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = p_schema AND p.proname LIKE 'post_%'
    )
    SELECT a.proname
    FROM all_posts a
    WHERE a.proname NOT IN (SELECT fn FROM referenced)
    ORDER BY a.proname
  LOOP
    v_rows := v_rows || '| ' || pgv.badge('WARN', 'warning') || ' | ' || pgv.esc(v_rec.proname) || ' | aucun data-rpc ne reference cette fonction |' || chr(10);
    v_warn := v_warn + 1;
  END LOOP;

  IF v_warn > 0 THEN
    v_reports := v_reports || pgv.dl(
      'Dead code POST', p_schema,
      'Bilan', pgv.badge(v_warn || ' non-reference(s)', 'warning'))
      || '<md>' || chr(10)
      || '| Niveau | Fonction | Detail |' || chr(10)
      || '|--------|----------|--------|' || chr(10)
      || v_rows
      || '</md>' || chr(10);
  END IF;

  -- 11. i18n: hardcoded French strings (schema-wide)
  v_rows := '';
  v_warn := 0;
  v_ok := 0;

  FOR v_rec IN
    WITH fn_scan AS (
      SELECT p.proname, pg_get_functiondef(p.oid) AS def
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = p_schema
        AND (p.proname LIKE 'get_%' OR p.proname LIKE 'post_%'
             OR p.proname IN ('nav_items', 'brand'))
    )
    SELECT proname,
           def ~ '[éèêëàâùûôîïüçÉÈÊËÀÂÙÛÔÎÏÜÇ]' AS has_fr,
           def LIKE '%pgv.t(%' AS has_t,
           CASE WHEN def ~ '[éèêëàâùûôîïüçÉÈÊËÀÂÙÛÔÎÏÜÇ]' AND NOT def LIKE '%pgv.t(%' THEN
             (regexp_match(def, '''([^'']*[éèêëàâùûôîïüçÉÈÊËÀÂÙÛÔÎÏÜÇ][^'']*)'''))[1]
           END AS sample
    FROM fn_scan
    ORDER BY proname
  LOOP
    IF v_rec.has_fr AND NOT v_rec.has_t THEN
      v_rows := v_rows || '| ' || pgv.badge('WARN', 'warning') || ' | ' || v_rec.proname || '() | `' || pgv.esc(coalesce(substr(v_rec.sample, 1, 50), '?')) || '` |' || chr(10);
      v_warn := v_warn + 1;
    ELSE
      v_ok := v_ok + 1;
    END IF;
  END LOOP;

  IF v_warn > 0 OR v_ok > 0 THEN
    v_reports := v_reports || pgv.dl(
      'i18n', p_schema,
      'Bilan',
        CASE WHEN v_warn > 0 THEN pgv.badge(v_warn || ' fonction(s) FR', 'warning') || ' ' ELSE '' END
        || CASE WHEN v_ok > 0 THEN pgv.badge(v_ok || ' ok', 'success') ELSE '' END)
      || '<md>' || chr(10)
      || '| Niveau | Source | Detail |' || chr(10)
      || '|--------|--------|--------|' || chr(10)
      || v_rows
      || '</md>' || chr(10);
  END IF;

  -- 12. HTML audit: raw HTML that should use pgv.* primitives (schema-wide)
  v_reports := v_reports || pgv.html_audit(p_schema);

  RETURN v_reports;
END;
$function$;
