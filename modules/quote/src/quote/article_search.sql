CREATE OR REPLACE FUNCTION quote.article_search(p_search text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  -- Priority 1: catalog.article (with categorie join)
  IF EXISTS (
    SELECT 1 FROM pg_namespace n
    JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = 'article'
   WHERE n.nspname = 'catalog'
  ) THEN
    EXECUTE
      'SELECT coalesce(jsonb_agg(j ORDER BY j->>''label''), ''[]''::jsonb)
       FROM (
         SELECT jsonb_build_object(
           ''value'', a.id::text,
           ''label'', coalesce(a.reference, ''#'' || a.id) || '' — '' || a.designation,
           ''detail'', coalesce(cat.nom, '''')
         ) AS j
         FROM catalog.article a
         LEFT JOIN catalog.categorie cat ON cat.id = a.categorie_id
        WHERE a.actif
          AND ($1 = '''' OR a.designation ILIKE ''%%'' || $1 || ''%%''
               OR coalesce(a.reference, '''') ILIKE ''%%'' || $1 || ''%%'')
        ORDER BY a.designation
        LIMIT 20
       ) sub'
    INTO v_result USING p_search;
    RETURN coalesce(v_result, '[]'::jsonb);
  END IF;

  -- Priority 2: stock.article fallback
  IF EXISTS (
    SELECT 1 FROM pg_namespace n
    JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = 'article'
   WHERE n.nspname = 'stock'
  ) THEN
    EXECUTE
      'SELECT coalesce(jsonb_agg(j ORDER BY j->>''label''), ''[]''::jsonb)
       FROM (
         SELECT jsonb_build_object(
           ''value'', a.id::text,
           ''label'', a.reference || '' — '' || a.designation,
           ''detail'', a.categorie
         ) AS j
         FROM stock.article a
        WHERE a.active = true
          AND ($1 = '''' OR a.designation ILIKE ''%%'' || $1 || ''%%''
               OR a.reference ILIKE ''%%'' || $1 || ''%%'')
        ORDER BY a.reference
        LIMIT 20
       ) sub'
    INTO v_result USING p_search;
    RETURN coalesce(v_result, '[]'::jsonb);
  END IF;

  RETURN '[]'::jsonb;
END;
$function$;
