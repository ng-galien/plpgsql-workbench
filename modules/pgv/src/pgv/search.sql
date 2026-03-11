CREATE OR REPLACE FUNCTION pgv.search(p_query text, p_schema text, p_limit integer DEFAULT 12, p_offset integer DEFAULT 0)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_results pgv.search_result[];
  v_r pgv.search_result;
  v_html text := '';
  v_count int := 0;
  v_total int := 0;
BEGIN
  -- Check module has a search provider
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = p_schema AND p.proname = 'search'
  ) THEN
    RETURN '<div class="pgv-empty"><h4>Recherche non disponible</h4><p>Le module ' || pgv.esc(p_schema) || ' n''a pas de fonction search().</p></div>';
  END IF;

  -- Call module search provider
  EXECUTE format(
    'SELECT array_agg(r ORDER BY r.score DESC) FROM %I.search($1, $2, $3) r',
    p_schema
  ) USING p_query, p_limit + 1, p_offset
  INTO v_results;

  IF v_results IS NULL OR array_length(v_results, 1) = 0 THEN
    RETURN '<div class="pgv-empty"><h4>Aucun resultat</h4><p>Aucune entite ne correspond a "' || pgv.esc(p_query) || '".</p></div>';
  END IF;

  v_total := array_length(v_results, 1);

  -- Render results (limit to p_limit, use +1 to detect hasMore)
  v_html := '<ul class="pgv-search-results">';
  FOREACH v_r IN ARRAY v_results LOOP
    v_count := v_count + 1;
    IF v_count > p_limit THEN EXIT; END IF;
    v_html := v_html || pgv.search_item(v_r);
  END LOOP;
  v_html := v_html || '</ul>';

  -- Has more indicator
  IF v_total > p_limit THEN
    v_html := v_html || '<div class="pgv-search-more" data-offset="' || (p_offset + p_limit) || '">...</div>';
  END IF;

  RETURN v_html;
END;
$function$;
