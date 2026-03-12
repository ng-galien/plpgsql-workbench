CREATE OR REPLACE FUNCTION purchase.article_options(p_search text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb := '[]'::jsonb;
BEGIN
  -- Priority: catalog > stock
  IF EXISTS (SELECT 1 FROM pg_namespace n
             JOIN pg_proc p ON p.pronamespace = n.oid AND p.proname = 'article_options'
             WHERE n.nspname = 'catalog'
             AND pg_get_function_arguments(p.oid) LIKE '%p_search text%') THEN
    EXECUTE format('SELECT catalog.article_options(%L)', p_search) INTO v_result;
    RETURN coalesce(v_result, '[]'::jsonb);
  END IF;

  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'stock') THEN
    EXECUTE format(
      'SELECT coalesce(jsonb_agg(jsonb_build_object(
         ''value'', id::text,
         ''label'', reference || '' — '' || designation,
         ''detail'', coalesce(unite, ''u'')
       )), ''[]''::jsonb)
       FROM stock.article
       WHERE active = true
         AND (%L = '''' OR reference ILIKE ''%%'' || %L || ''%%'' OR designation ILIKE ''%%'' || %L || ''%%'')
       ORDER BY reference
       LIMIT 30',
      p_search, p_search, p_search
    ) INTO v_result;
  END IF;

  RETURN coalesce(v_result, '[]'::jsonb);
END;
$function$;
