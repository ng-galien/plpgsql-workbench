CREATE OR REPLACE FUNCTION catalog.category_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
  v_article_count int;
  v_has_children boolean;
BEGIN
  SELECT to_jsonb(c) || jsonb_build_object(
    'parent_name', p.name,
    'article_count', (SELECT count(*)::int FROM catalog.article a WHERE a.category_id = c.id)
  ) INTO v_result
  FROM catalog.category c
  LEFT JOIN catalog.category p ON p.id = c.parent_id
  WHERE c.id = p_id::int;

  IF v_result IS NULL THEN RETURN NULL; END IF;

  v_article_count := (v_result->>'article_count')::int;
  v_has_children := EXISTS(SELECT 1 FROM catalog.category WHERE parent_id = p_id::int);

  IF v_article_count = 0 AND NOT v_has_children THEN
    v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
      jsonb_build_object('method', 'delete', 'uri', 'catalog://category/' || p_id)
    ));
  ELSE
    v_result := v_result || jsonb_build_object('actions', '[]'::jsonb);
  END IF;

  RETURN v_result;
END;
$function$;
