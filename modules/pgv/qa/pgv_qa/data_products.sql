CREATE OR REPLACE FUNCTION pgv_qa.data_products(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_status   text := p_params->>'p_status';
  v_category text := p_params->>'p_category';
  v_q        text := p_params->>'q';
  v_offset   int  := coalesce((p_params->>'_offset')::int, 0);
  v_size     int  := coalesce((p_params->>'_size')::int, 20);
  v_rows     jsonb;
  v_has_more bool;
BEGIN
  SELECT coalesce(jsonb_agg(row), '[]') INTO v_rows
  FROM (
    SELECT jsonb_build_array(t.id, t.name, t.category, t.price, t.status) AS row
    FROM pgv_qa.product t
    WHERE (v_status IS NULL OR t.status = v_status)
      AND (v_category IS NULL OR t.category = v_category)
      AND (v_q IS NULL OR t.search_vec @@ plainto_tsquery('pgv_search', v_q))
    ORDER BY t.id
    LIMIT v_size + 1 OFFSET v_offset
  ) sub;

  v_has_more := jsonb_array_length(v_rows) > v_size;
  IF v_has_more THEN
    v_rows := v_rows - v_size;
  END IF;

  RETURN jsonb_build_object('rows', v_rows, 'has_more', v_has_more);
END;
$function$;
