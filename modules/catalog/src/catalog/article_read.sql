CREATE OR REPLACE FUNCTION catalog.article_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
  v_active boolean;
BEGIN
  SELECT to_jsonb(a) || jsonb_build_object(
    'category_name', c.name,
    'unit_label', u.label
  ) INTO v_result
  FROM catalog.article a
  LEFT JOIN catalog.category c ON c.id = a.category_id
  LEFT JOIN catalog.unit u ON u.code = a.unit
  WHERE a.id = p_id::int;

  IF v_result IS NULL THEN RETURN NULL; END IF;

  v_active := (v_result->>'active')::boolean;
  IF v_active THEN
    v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
      jsonb_build_object('method', 'deactivate', 'uri', 'catalog://article/' || p_id || '/deactivate'),
      jsonb_build_object('method', 'delete', 'uri', 'catalog://article/' || p_id)
    ));
  ELSE
    v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
      jsonb_build_object('method', 'activate', 'uri', 'catalog://article/' || p_id || '/activate'),
      jsonb_build_object('method', 'delete', 'uri', 'catalog://article/' || p_id)
    ));
  END IF;

  RETURN v_result;
END;
$function$;
